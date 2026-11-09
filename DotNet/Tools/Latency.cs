using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Threading;

// Background TCP connect latency probe for pool hosts. Start() measures a batch of
// host:port endpoints on its own threads, Collect() hands the finished results to
// PowerShell. Nothing in here blocks the caller.
public static class RBMLatency
{
    private static readonly object Sync = new object();
    private static Dictionary<string, double> Results = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
    private static int Running = 0;
    private static int Workers = 0;

    public static bool IsBusy
    {
        get { return Interlocked.CompareExchange(ref Running, 0, 0) != 0; }
    }

    // endpoints as "host:port"; returns false while a previous batch is still running
    public static bool Start(string[] endpoints, int samples, int timeoutMs, int parallel)
    {
        if (endpoints == null || endpoints.Length == 0) return false;
        if (Interlocked.CompareExchange(ref Running, 1, 0) != 0) return false;

        Queue<string> queue = new Queue<string>(endpoints);
        int count = Math.Max(1, Math.Min(parallel, endpoints.Length));
        Workers = count;
        for (int i = 0; i < count; i++)
        {
            Thread worker = new Thread(delegate()
            {
                try
                {
                    while (true)
                    {
                        string endpoint;
                        lock (queue)
                        {
                            if (queue.Count == 0) break;
                            endpoint = queue.Dequeue();
                        }
                        double ms = Measure(endpoint, samples, timeoutMs);
                        lock (Sync) { Results[endpoint] = ms; }
                    }
                }
                catch { }
                finally
                {
                    if (Interlocked.Decrement(ref Workers) == 0) Interlocked.Exchange(ref Running, 0);
                }
            });
            worker.IsBackground = true;
            worker.Name = "RBMLatency";
            worker.Start();
        }
        return true;
    }

    // measurements finished so far (ms, -1 = unreachable), cleared on read
    public static Dictionary<string, double> Collect()
    {
        lock (Sync)
        {
            Dictionary<string, double> done = Results;
            Results = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            return done;
        }
    }

    // lowest connect time of several samples against the resolved address, -1 when none succeeded.
    // IPv4 is preferred because that is what the miners connect to.
    public static double Measure(string endpoint, int samples, int timeoutMs)
    {
        if (string.IsNullOrEmpty(endpoint)) return -1;
        int sep = endpoint.LastIndexOf(':');
        if (sep <= 0) return -1;
        string host = endpoint.Substring(0, sep);
        int port;
        if (!int.TryParse(endpoint.Substring(sep + 1), out port) || port < 1 || port > 65535) return -1;
        if (samples < 1) samples = 1;
        if (timeoutMs < 100) timeoutMs = 100;

        IPAddress address = null;
        try
        {
            IPAddress[] addresses = Dns.GetHostAddresses(host);
            foreach (IPAddress a in addresses)
            {
                if (a.AddressFamily == AddressFamily.InterNetwork) { address = a; break; }
            }
            if (address == null && addresses.Length > 0) address = addresses[0];
        }
        catch { }
        if (address == null) return -1;

        double best = -1;
        int failed = 0;
        for (int i = 0; i < samples; i++)
        {
            Socket socket = null;
            try
            {
                socket = new Socket(address.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
                Stopwatch watch = Stopwatch.StartNew();
                IAsyncResult ar = socket.BeginConnect(address, port, null, null);
                if (ar.AsyncWaitHandle.WaitOne(timeoutMs))
                {
                    socket.EndConnect(ar);
                    watch.Stop();
                    double ms = watch.Elapsed.TotalMilliseconds;
                    if (best < 0 || ms < best) best = ms;
                }
                else failed++;
            }
            catch { failed++; }
            finally
            {
                if (socket != null) { try { socket.Close(); } catch { } }
            }
            // a host that ignores two connects in a row is down, do not wait for the rest
            if (best < 0 && failed >= 2) break;
            if (i + 1 < samples) Thread.Sleep(30);
        }
        return best;
    }
}
