using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace RBMTools
{
  public static class process
  {
    public static List<string> output = null;
    
    public static List<string> exec(string executable, string args = "", string cwd = "", string verb = "runas", int timeout = 5) {

      output = new List<string>();

      //* Create your Process
      using (Process process = new Process()) {
        process.StartInfo.FileName = executable;
        process.StartInfo.UseShellExecute = false;
        process.StartInfo.CreateNoWindow = true;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;

        //* Optional process configuration
        if (!String.IsNullOrEmpty(args)) { process.StartInfo.Arguments = args; }
        if (!String.IsNullOrEmpty(cwd)) { process.StartInfo.WorkingDirectory = cwd; }
        if (!String.IsNullOrEmpty(verb)) { process.StartInfo.Verb = verb; }

        //* Set your output and error (asynchronous) handlers
        process.OutputDataReceived += new DataReceivedEventHandler(OutputHandler);
        process.ErrorDataReceived += new DataReceivedEventHandler(OutputHandler);

        //* Start process and handlers
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        if (!process.WaitForExit(timeout * 1000)) {
          process.Kill();
        }
      }

      //* Return the output
      return output;
    }
    public static void OutputHandler(object sendingProcess, DataReceivedEventArgs outLine) {
      output.Add(String.IsNullOrEmpty(outLine.Data)? "":outLine.Data);
    }
  }
}