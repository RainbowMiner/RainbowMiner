using System;
using System.Text;
using System.Text.RegularExpressions;
using System.IO;
using System.Collections.Generic;
using System.Management.Automation;

public static class PSMemSafeOps
{
    // 1. String Comparison & Equality Methods
    public static bool EqualsIgnoreCase(string str1, string str2)
    {
        return str1 != null && str2 != null && string.Equals(str1, str2, StringComparison.OrdinalIgnoreCase);
    }

    public static int CompareIgnoreCase(string str1, string str2)
    {
        if (str1 == null && str2 == null) return 0;
        if (str1 == null) return -1;
        if (str2 == null) return 1;
        return string.Compare(str1, str2, StringComparison.OrdinalIgnoreCase);
    }

    public static int CompareToSafe(string str1, string str2)
    {
        if (str1 == null && str2 == null) return 0;
        if (str1 == null) return -1;
        return str1.CompareTo(str2);
    }

    // 2. String Manipulation Methods
    public static string ConcatEfficient(params string[] values)
    {
        return string.Concat(values);
    }

    public static string JoinEfficient(string separator, string[] values)
    {
        return string.Join(separator, values);
    }

    public static string ReplaceEfficient(string input, string oldValue, string newValue)
    {
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(oldValue)) return input;
        return input.Replace(oldValue, newValue);
    }

    public static string SubstringSafe(string input, int start, int length)
    {
        if (string.IsNullOrEmpty(input) || start < 0 || length < 0 || start + length > input.Length)
            return string.Empty;
        return input.Substring(start, length);
    }

    public static string TrimEfficient(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;
        int start = 0, end = input.Length - 1;
        while (start <= end && char.IsWhiteSpace(input[start])) start++;
        while (end >= start && char.IsWhiteSpace(input[end])) end--;
        return input.Substring(start, end - start + 1);
    }

    public static string TrimStartEfficient(string input)
    {
        if (input == null) return string.Empty;
        return input.TrimStart();
    }

    public static string TrimEndEfficient(string input)
    {
        if (input == null) return string.Empty;
        return input.TrimEnd();
    }

    // 3. String Formatting & Interpolation
    public static string FormatEfficient(string format, params object[] args)
    {
        return string.Format(format, args);
    }

    public static string InterpolateEfficient(string template, params object[] args)
    {
        return string.Format(template, args);
    }

    // 4. String Splitting & Joining
    public static string[] SplitEfficient(string input, char separator)
    {
        if (string.IsNullOrEmpty(input)) return new string[0];
        return input.Split(new char[] { separator }, StringSplitOptions.RemoveEmptyEntries);
    }

    public static char[] ToCharArrayEfficient(string input)
    {
        return string.IsNullOrEmpty(input) ? new char[0] : input.ToCharArray();
    }

    // 5. String Matching & Search
    public static bool ContainsSafe(string input, string value)
    {
        return input != null && value != null && input.Contains(value);
    }

    public static bool StartsWithSafe(string input, string value)
    {
        return input != null && value != null && input.StartsWith(value);
    }

    public static bool EndsWithSafe(string input, string value)
    {
        return input != null && value != null && input.EndsWith(value);
    }

    public static int IndexOfSafe(string input, string value)
    {
        if (input == null || value == null) return -1;
        return input.IndexOf(value, StringComparison.Ordinal);
    }

    public static int LastIndexOfSafe(string input, string value)
    {
        if (input == null || value == null) return -1;
        return input.LastIndexOf(value, StringComparison.Ordinal);
    }

    // 6. File Operations
    public static string[] ReadFileEfficient(string path)
    {
        if (!File.Exists(path)) return new string[0];
        return File.ReadAllLines(path, Encoding.UTF8);
    }

    public static void WriteFileEfficient(string path, string[] lines)
    {
        if (lines == null || lines.Length == 0) return;
        File.WriteAllLines(path, lines, Encoding.UTF8);
    }

    // 7. Regex Matching
    public static Dictionary<int, string> MatchEfficient(string input, string pattern)
    {
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(pattern)) return null;

        var match = Regex.Match(input, pattern, RegexOptions.Compiled);
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
