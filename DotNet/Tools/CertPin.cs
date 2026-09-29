using System;
using System.Collections.Generic;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

// Certificate checks for https servers (ServerSSL / ServerCertHash). A registered host either
// carries a fingerprint (SHA-256 = 64 hex, SHA-1 = 40 hex) that the presented certificate must
// match, or the marker CHAIN, which means the normal chain validation must pass (a public
// certificate such as Let's Encrypt). Every other host is accepted unchanged: the pool and api
// requests never verified certificates before, and that stays as it is.
public static class RBMCertPin
{
    public const string Chain = "CHAIN";
    private static readonly object _lock = new object();
    private static readonly Dictionary<string, string> _pins = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

    public static string Normalize(string hash)
    {
        if (hash == null) return "";
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        foreach (char c in hash)
        {
            if (Uri.IsHexDigit(c)) sb.Append(char.ToUpperInvariant(c));
        }
        return sb.ToString();
    }

    // register a host: a fingerprint pins the certificate, anything else asks for chain validation
    public static void Set(string host, string hash)
    {
        if (string.IsNullOrEmpty(host)) return;
        string pin = Normalize(hash);
        if (pin.Length != 40 && pin.Length != 64) pin = Chain;
        lock (_lock) { _pins[host] = pin; }
    }

    public static void Remove(string host)
    {
        if (string.IsNullOrEmpty(host)) return;
        lock (_lock) { _pins.Remove(host); }
    }

    public static string Get(string host)
    {
        if (string.IsNullOrEmpty(host)) return "";
        string pin;
        lock (_lock) { return _pins.TryGetValue(host, out pin) ? pin : ""; }
    }

    public static void Clear()
    {
        lock (_lock) { _pins.Clear(); }
    }

    // the callback's sender is a HttpWebRequest (.NET Framework), a HttpRequestMessage or a SslStream (.NET Core)
    public static string GetHost(object sender)
    {
        if (sender == null) return null;
        try
        {
            Type t = sender.GetType();
            System.Reflection.PropertyInfo p = t.GetProperty("RequestUri");
            if (p != null)
            {
                Uri u = p.GetValue(sender, null) as Uri;
                if (u != null) return u.Host;
            }
            p = t.GetProperty("TargetHostName");
            if (p != null) return p.GetValue(sender, null) as string;
        }
        catch { }
        return null;
    }

    public static string Fingerprint(X509Certificate certificate, bool sha1)
    {
        byte[] raw = certificate.GetRawCertData();
        byte[] hash;
        if (sha1)
        {
            using (SHA1 h = SHA1.Create()) { hash = h.ComputeHash(raw); }
        }
        else
        {
            using (SHA256 h = SHA256.Create()) { hash = h.ComputeHash(raw); }
        }
        return BitConverter.ToString(hash).Replace("-", "");
    }

    public static bool Validate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
    {
        string pin = Get(GetHost(sender));
        if (pin.Length == 0) return true;
        if (pin == Chain) return sslPolicyErrors == SslPolicyErrors.None;
        if (certificate == null) return false;
        try
        {
            return string.Equals(Fingerprint(certificate, pin.Length == 40), pin, StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    public static RemoteCertificateValidationCallback GetCallback()
    {
        return new RemoteCertificateValidationCallback(Validate);
    }
}
