using System;
using System.Text;
using System.Text.RegularExpressions;
using System.IO;
using System.Collections.Generic;
using System.Management.Automation;

public static class PSMemSafeOps
{

    public static bool IsNetcoreApp()
    {
#if NETCOREAPP3_0_OR_GREATER
        return true;
#else
        return false;
#endif
    }

    // 1. String Comparison
    public static bool EqualsIgnoreCase(string str1, string str2)
    {
#if NETCOREAPP3_0_OR_GREATER
        return MemoryExtensions.Equals(str1.AsSpan(), str2.AsSpan(), StringComparison.OrdinalIgnoreCase);
#else
        return str1 != null && str2 != null && string.Equals(str1, str2, StringComparison.OrdinalIgnoreCase);
#endif
    }

    public static int CompareIgnoreCase(string str1, string str2)
    {
        if (str1 == null && str2 == null) return 0;
        if (str1 == null) return -1;
        if (str2 == null) return 1;
        return string.Compare(str1, str2, StringComparison.OrdinalIgnoreCase);
    }

    // 2. Optimized String Manipulation
    public static string Concat(string str1, string str2)
    {
#if NETCOREAPP3_0_OR_GREATER
        return string.Concat(str1 ?? "", str2 ?? "");
#else
        if (str1 == null) str1 = "";
        if (str2 == null) str2 = "";
        return str1 + str2;
#endif
    }

    public static string Replace(string input, string oldValue, string newValue)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.Replace(oldValue, newValue) ?? input;
#else
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(oldValue)) return input;
        return input.Replace(oldValue, newValue);
#endif
    }

    public static string Substring(string input, int start, int length)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.AsSpan(start, length).ToString() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input) || start < 0 || length < 0 || start + length > input.Length)
            return string.Empty;
        return input.Substring(start, length);
#endif
    }

    public static string Trim(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.Trim() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.Trim();
#endif
    }

    public static string TrimStart(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.TrimStart() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.TrimStart();
#endif
    }

    public static string TrimEnd(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.TrimEnd() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.TrimEnd();
#endif
    }

    public static string ToLower(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.ToLowerInvariant() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.ToLowerInvariant();
#endif
}

    public static string ToUpper(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.ToUpperInvariant() ?? string.Empty;
#else
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.ToUpperInvariant();
#endif
    }

    // 3. Optimized Formatting
    public static string Format(string format, params object[] args)
    {
#if NETCOREAPP3_0_OR_GREATER
        return args.Length > 0 ? string.Format(format, args) : format ?? string.Empty;
#else
        if (string.IsNullOrEmpty(format)) return string.Empty;
        return args.Length > 0 ? string.Format(format, args) : format;
#endif
    }

    // 4. Optimized Splitting & Joining
    public static string[] Split(string input, char separator)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.Split(new char[] { separator }, StringSplitOptions.RemoveEmptyEntries) ?? new string[0];
#else
        if (string.IsNullOrEmpty(input)) return new string[0];
        return input.Split(new char[] { separator }, StringSplitOptions.RemoveEmptyEntries);
#endif
    }

    public static string Join(string separator, string[] values)
    {
#if NETCOREAPP3_0_OR_GREATER
        return string.Join(separator, values ?? new string[0]);
#else
        if (values == null) return string.Empty;
        return string.Join(separator, values);
#endif
    }

    public static char[] ToCharArray(string input)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.ToCharArray() ?? new char[0];
#else
        if (string.IsNullOrEmpty(input)) return new char[0];
        return input.ToCharArray();
#endif
    }

    // 5. Optimized Matching & Search
    public static bool Contains(string input, string value)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.Contains(value) ?? false;
#else
        return input != null && value != null && input.Contains(value);
#endif
    }

    public static bool StartsWith(string input, string value)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.StartsWith(value) ?? false;
#else
        return input != null && value != null && input.StartsWith(value);
#endif
    }

    public static bool EndsWith(string input, string value)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.EndsWith(value) ?? false;
#else
        return input != null && value != null && input.EndsWith(value);
#endif
    }

    public static int IndexOf(string input, string value)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.IndexOf(value) ?? -1;
#else
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(value)) return -1;
        return input.IndexOf(value);
#endif
    }

    public static int LastIndexOf(string input, string value)
    {
#if NETCOREAPP3_0_OR_GREATER
        return input?.LastIndexOf(value) ?? -1;
#else
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(value)) return -1;
        return input.LastIndexOf(value);
#endif
    }

    // 6. File Operations
    public static object ReadFile(string filePath, bool expandLines, bool throwError)
    {
#if NETCOREAPP3_0_OR_GREATER
        try
        {
            if (filePath == null || !File.Exists(filePath))
                return null;

            using (FileStream stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (StreamReader reader = new StreamReader(stream))
            {
                return expandLines ? reader.ReadToEnd().Split('\n') : reader.ReadToEnd();
            }
        }
        catch (Exception ex)
        {
            if (throwError)
                throw new Exception($"Error reading file '{filePath}': {ex.Message}", ex);
            return null;
        }
#else
        FileStream stream = null;
        StreamReader reader = null;
        try
        {
            if (filePath == null || !File.Exists(filePath))
                return null;

            stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            reader = new StreamReader(stream);

            if (expandLines)
            {
                var lines = new List<string>();
                while (!reader.EndOfStream)
                {
                    lines.Add(reader.ReadLine());
                }
                return lines.ToArray();  // Returns an array of lines
            }
            else
            {
                return reader.ReadToEnd();  // Returns a single string
            }
        }
        catch (Exception ex)
        {
            if (throwError)
                throw new Exception("Error reading file '" + filePath+ "': "+ex.Message, ex);
            return null;
        }
        finally
        {
            if (reader != null) reader.Dispose();
            if (stream != null) stream.Dispose();
        }
#endif
    }

    public static void WriteFile(string path, string[] lines)
    {
        if (string.IsNullOrEmpty(path) || lines == null || lines.Length == 0) return;
        File.WriteAllLines(path, lines, Encoding.UTF8);
    }

    // 7. Optimized Regex Matching
    public static Dictionary<int, string> Match(string input, string pattern)
    {
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(pattern)) return null;

#if NETCOREAPP3_0_OR_GREATER
        var match = Regex.Match(input, pattern, RegexOptions.Compiled);
#else
        var match = Regex.Match(input, pattern);
#endif
        if (!match.Success) return null;

        var matches = new Dictionary<int, string>();
        for (int i = 0; i < match.Groups.Count; i++)
        {
            matches[i] = match.Groups[i].Value;
        }

        return matches;
    }

    // 8. Object handling
    public static PSObject CopyObject(PSObject source)
    {
        if (source == null) return null;

        PSObject copy = new PSObject();
        foreach (var prop in source.Properties)
        {
            copy.Properties.Add(new PSNoteProperty(prop.Name, prop.Value));
        }
        return copy;
    }
}
