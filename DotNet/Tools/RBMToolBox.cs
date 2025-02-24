using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Reflection;

public static class RBMToolBox
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

    public static string ReplaceRegex(string input, string pattern, string replacement)
    {
#if NETCOREAPP3_0_OR_GREATER
    return string.IsNullOrEmpty(input) ? input : System.Text.RegularExpressions.Regex.Replace(input, pattern, replacement);
#else
        if (string.IsNullOrEmpty(input)) return input;
        return System.Text.RegularExpressions.Regex.Replace(input, pattern, replacement);
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
    public static string[] Split(string input, string[] separators, int limit = 0, bool removeEmptyEntries = true)
    {
        if (string.IsNullOrEmpty(input) || separators == null || separators.Length == 0)
            return new string[0];

        StringSplitOptions options = removeEmptyEntries ? StringSplitOptions.RemoveEmptyEntries : StringSplitOptions.None;

        string[] result = limit > 0 ? input.Split(separators, limit, options) : input.Split(separators, options);

        return result;
    }

    public static string[] SplitRegex(string input, string pattern, bool removeEmptyEntries = true)
    {
        if (string.IsNullOrEmpty(input) || string.IsNullOrEmpty(pattern))
            return new string[0];

        string[] result = Regex.Split(input, pattern);

        if (removeEmptyEntries)
        {
            List<string> filtered = new List<string>();
            foreach (string item in result)
            {
                if (!string.IsNullOrEmpty(item))
                    filtered.Add(item);
            }
            return filtered.ToArray();
        }

        return result;
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
    public static object ReadFile(string filePath, bool expandLines = false, bool throwError = false)
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
    public static bool CompareObject(object obj1, object obj2)
    {
        if (obj1 == null && obj2 == null) return true;
        if (obj1 == null || obj2 == null) return false;

        obj1 = UnwrapPSObject(obj1);
        obj2 = UnwrapPSObject(obj2);

        Type type1 = obj1.GetType();
        Type type2 = obj2.GetType();

        if (obj1 is ValueType && obj2 is ValueType && !(obj1 is bool) && !(obj1 is char) && !(obj1 is DateTime))
        {
            return Convert.ToDecimal(obj1).Equals(Convert.ToDecimal(obj2));
        }

        if (type1 != type2)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (obj1 is PSObject psObj && obj2 is Hashtable hash)
                return ComparePSObjectToHashtable(psObj, hash);

            if (obj2 is PSObject psObjOther && obj1 is Hashtable hashOther)
                return ComparePSObjectToHashtable(psObjOther, hashOther);
#else
            if (obj1 is PSObject && obj2 is Hashtable)
                return ComparePSObjectToHashtable((PSObject)obj1, (Hashtable)obj2);

            if (obj2 is PSObject && obj1 is Hashtable)
                return ComparePSObjectToHashtable((PSObject)obj2, (Hashtable)obj1);
#endif
            return false;
        }

        if (obj1 is ValueType || obj1 is string) return obj1.Equals(obj2);
#if NETCOREAPP3_0_OR_GREATER
        if (obj1 is PSObject psObj1 && obj2 is PSObject psObj2) return ComparePSCustomObjects(psObj1, psObj2);
        if (obj1 is Hashtable hash1 && obj2 is Hashtable hash2) return CompareHashtables(hash1, hash2);
        if (obj1 is Array arr1 && obj2 is Array arr2) return CompareArrays(arr1, arr2);
#else
        if (obj1 is PSObject && obj2 is PSObject) return ComparePSCustomObjects((PSObject)obj1, (PSObject)obj2);
        if (obj1 is Hashtable && obj2 is Hashtable) return CompareHashtables((Hashtable)obj1, (Hashtable)obj2);
        if (obj1 is Array && obj2 is Array) return CompareArrays((Array)obj1, (Array)obj2);
#endif
        return obj1.Equals(obj2);
    }

    public static bool ComparePSObjectToHashtable(PSObject psObj, Hashtable hash)
    {
        if (psObj == null || hash == null) return false;

        var properties = psObj.Properties;

        // Count properties manually (since .Count is unavailable)
        int propCount = 0;
        var enumerator = properties.GetEnumerator();
        while (enumerator.MoveNext()) propCount++;

        // Quick check: If number of properties doesn't match number of hashtable keys, return false
        if (propCount != hash.Count) return false;

        foreach (var prop in properties)
        {
            if (!hash.ContainsKey(prop.Name))
                return false;

            if (!CompareObject(prop.Value, hash[prop.Name]))
                return false;
        }

        return true;
    }

    public static bool ComparePSCustomObjects(PSObject obj1, PSObject obj2)
    {
        if (obj1 == null && obj2 == null) return true;
        if (obj1 == null || obj2 == null) return false;

        var props1 = obj1.Properties;
        var props2 = obj2.Properties;

        int count1 = 0, count2 = 0;
        var enumerator1 = props1.GetEnumerator();
        var enumerator2 = props2.GetEnumerator();

        while (enumerator1.MoveNext()) count1++;
        while (enumerator2.MoveNext()) count2++;

        if (count1 != count2) return false;

        Dictionary<string, PSPropertyInfo> lookup2 = new Dictionary<string, PSPropertyInfo>();

        foreach (var prop in props2)
            lookup2[prop.Name] = prop;

        foreach (var prop1 in props1)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (!lookup2.TryGetValue(prop1.Name, out var prop2))
                return false;
#else
            PSPropertyInfo prop2;

            if (!lookup2.TryGetValue(prop1.Name, out prop2))
                return false;
#endif

            if (!CompareObject(prop1.Value, prop2.Value))
                return false;
        }

        return true;
    }

    public static bool CompareHashtables(Hashtable hash1, Hashtable hash2)
    {
        if (hash1 == null && hash2 == null) return true;
        if (hash1 == null || hash2 == null) return false;
        if (hash1.Count != hash2.Count) return false;

        foreach (object key in hash1.Keys)
        {
            if (!hash2.ContainsKey(key)) return false;
            if (!CompareObject(hash1[key], hash2[key])) return false;
        }
        return true;
    }

    public static bool CompareArrays(Array arr1, Array arr2, bool sort = false)
    {
        if (arr1 == null && arr2 == null) return true;
        if (arr1 == null || arr2 == null) return false;

        if (arr1.Length != arr2.Length) return false;

        if (sort)
        {
            arr1 = (object[])arr1.Clone();
            arr2 = (object[])arr2.Clone();
            Array.Sort(arr1);
            Array.Sort(arr2);
        }

        for (int i = 0; i < arr1.Length; i++)
        {
            if (!CompareObject(arr1.GetValue(i), arr2.GetValue(i))) return false;
        }
        return true;
    }

    public static bool CompareObjectIgnoreCase(object obj1, object obj2)
    {
        if (obj1 == null && obj2 == null) return true;
        if (obj1 == null || obj2 == null) return false;

        obj1 = UnwrapPSObject(obj1);
        obj2 = UnwrapPSObject(obj2);

        Type type1 = obj1.GetType();
        Type type2 = obj2.GetType();

        if (obj1 is ValueType && obj2 is ValueType && !(obj1 is bool) && !(obj1 is char) && !(obj1 is DateTime))
        {
            return Convert.ToDecimal(obj1).Equals(Convert.ToDecimal(obj2));
        }

        if (type1 != type2)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (obj1 is PSObject psObj && obj2 is Hashtable hash)
                return ComparePSObjectToHashtableIgnoreCase(psObj, hash);

            if (obj2 is PSObject psObjOther && obj1 is Hashtable hashOther)
                return ComparePSObjectToHashtableIgnoreCase(psObjOther, hashOther);
#else
            if (obj1 is PSObject && obj2 is Hashtable)
                return ComparePSObjectToHashtableIgnoreCase((PSObject)obj1, (Hashtable)obj2);

            if (obj2 is PSObject && obj1 is Hashtable)
                return ComparePSObjectToHashtableIgnoreCase((PSObject)obj2, (Hashtable)obj1);
#endif
            return false;
        }

        if (obj1 is ValueType || obj1 is string) return CompareValuesIgnoreCase(obj1, obj2);
#if NETCOREAPP3_0_OR_GREATER
        if (obj1 is PSObject psObj1 && obj2 is PSObject psObj2) return ComparePSCustomObjectsIgnoreCase(psObj1, psObj2);
        if (obj1 is Hashtable hash1 && obj2 is Hashtable hash2) return CompareHashtablesIgnoreCase(hash1, hash2);
        if (obj1 is Array arr1 && obj2 is Array arr2) return CompareArraysIgnoreCase(arr1, arr2);
#else
        if (obj1 is PSObject && obj2 is PSObject) return ComparePSCustomObjectsIgnoreCase((PSObject)obj1, (PSObject)obj2);
        if (obj1 is Hashtable && obj2 is Hashtable) return CompareHashtablesIgnoreCase((Hashtable)obj1, (Hashtable)obj2);
        if (obj1 is Array && obj2 is Array) return CompareArraysIgnoreCase((Array)obj1, (Array)obj2);
#endif
        return obj1.Equals(obj2);
    }


    public static bool ComparePSObjectToHashtableIgnoreCase(PSObject psObj, Hashtable hash)
    {
        if (psObj == null || hash == null) return false;

        var properties = psObj.Properties;

        // Count properties manually (since .Count is unavailable)
        int propCount = 0;
        var enumerator = properties.GetEnumerator();
        while (enumerator.MoveNext()) propCount++;

        // Quick check: If number of properties doesn't match number of hashtable keys, return false
        if (propCount != hash.Count) return false;

        Dictionary<string, object> lookupHash = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

        foreach (DictionaryEntry entry in hash)
        {
            if (entry.Key != null)
                lookupHash[entry.Key.ToString()] = entry.Value;
        }

        foreach (var prop in properties)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (!lookupHash.TryGetValue(prop.Name, out object hashValue))
                return false;
#else
            object hashValue;

            if (!lookupHash.TryGetValue(prop.Name, out hashValue))
                return false;
#endif

            if (!CompareObjectIgnoreCase(prop.Value, hashValue))
                return false;
        }

        return true;
    }

    public static bool ComparePSCustomObjectsIgnoreCase(PSObject obj1, PSObject obj2)
    {
        if (obj1 == null && obj2 == null) return true;
        if (obj1 == null || obj2 == null) return false;

        var props1 = obj1.Properties;
        var props2 = obj2.Properties;

        int count1 = 0, count2 = 0;
        var enumerator1 = props1.GetEnumerator();
        var enumerator2 = props2.GetEnumerator();

        while (enumerator1.MoveNext()) count1++;
        while (enumerator2.MoveNext()) count2++;

        if (count1 != count2) return false;

        Dictionary<string, PSPropertyInfo> lookup2 = new Dictionary<string, PSPropertyInfo>(StringComparer.OrdinalIgnoreCase);

        foreach (var prop in props2)
            lookup2[prop.Name] = prop;

        foreach (var prop1 in props1)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (!lookup2.TryGetValue(prop1.Name, out var prop2))
                return false;
#else
            PSPropertyInfo prop2;

            if (!lookup2.TryGetValue(prop1.Name, out prop2))
                return false;
#endif

            if (!CompareObjectIgnoreCase(prop1.Value, prop2.Value))
                return false;
        }

        return true;
    }

    public static bool CompareHashtablesIgnoreCase(Hashtable hash1, Hashtable hash2)
    {
        if (hash1 == null && hash2 == null) return true;
        if (hash1 == null || hash2 == null) return false;
        if (hash1.Count != hash2.Count) return false;

        Dictionary<string, object> lookup2 = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

        foreach (DictionaryEntry entry in hash2)
        {
            if (entry.Key != null)
                lookup2[entry.Key.ToString()] = entry.Value;
        }

        foreach (DictionaryEntry entry in hash1)
        {
#if NETCOREAPP3_0_OR_GREATER
            if (!lookup2.TryGetValue(entry.Key.ToString(), out object value2))
                return false;
#else
            object value2;

            if (!lookup2.TryGetValue(entry.Key.ToString(), out value2))
                return false;
#endif

            if (!CompareObjectIgnoreCase(entry.Value, value2))
                return false;
        }

        return true;
    }

    public static bool CompareArraysIgnoreCase(Array arr1, Array arr2, bool sort = false)
    {
        if (arr1 == null && arr2 == null) return true;
        if (arr1 == null || arr2 == null) return false;
        if (arr1.Length != arr2.Length) return false;

        if (sort)
        {
            arr1 = (object[])arr1.Clone();
            arr2 = (object[])arr2.Clone();
            Array.Sort(arr1, StringComparer.OrdinalIgnoreCase);
            Array.Sort(arr2, StringComparer.OrdinalIgnoreCase);
        }

        for (int i = 0; i < arr1.Length; i++)
        {
            if (!CompareObjectIgnoreCase(arr1.GetValue(i), arr2.GetValue(i))) return false;
        }
        return true;
    }

    public static bool CompareValuesIgnoreCase(object obj1, object obj2)
    {
#if NETCOREAPP3_0_OR_GREATER
        if (obj1 is string str1 && obj2 is string str2)
        {
            return string.Equals(str1, str2, StringComparison.OrdinalIgnoreCase);
        }
#else
        if (obj1 is string && obj2 is string)
        {
            string str1 = (string)obj1;
            string str2 = (string)obj2;
            return string.Equals(str1, str2, StringComparison.OrdinalIgnoreCase);
        }
#endif
        return obj1.Equals(obj2);
    }

    public static bool IsIntersect(object obj1, object obj2)
    {
        obj1 = UnwrapPSObject(obj1);
        obj2 = UnwrapPSObject(obj2);

        object[] array1 = ConvertToValueTypeOrStringArray(obj1);
        object[] array2 = ConvertToValueTypeOrStringArray(obj2);

        HashSet<object> set1 = new HashSet<object>(array1);
        foreach (var value in array2)
        {
            if (set1.Contains(value))
                return true;
        }

        return false;
    }

    // Private functions
    private static object UnwrapPSObject(object obj)
    {
#if NETCOREAPP3_0_OR_GREATER
        if (obj is PSObject psObj)
        {
            object baseObj = psObj.BaseObject;

            if (baseObj is PSCustomObject)
                return obj;

            if (baseObj == null || baseObj is ValueType || baseObj is string || baseObj is DBNull || baseObj is Hashtable)
                return baseObj;

            return obj;
        }
#else
        if (obj is PSObject)
        {
            object baseObj = ((PSObject)obj).BaseObject;

            if (baseObj is PSCustomObject)
                return obj;

            if (baseObj == null || baseObj is ValueType || baseObj is string || baseObj is DBNull || baseObj is Hashtable)
                return baseObj;

            return obj;
        }
#endif
        return obj;
    }

    // 9. Math functions
#if NETCOREAPP3_0_OR_GREATER
    // Round
    public static double Round(double value, int digits) => Math.Round(value, digits);
    public static decimal Round(decimal value, int digits) => Math.Round(value, digits);

    // Min
    public static double Min(double a, double b) => Math.Min(a, b);
    public static decimal Min(decimal a, decimal b) => Math.Min(a, b);

    // Max
    public static double Max(double a, double b) => Math.Max(a, b);
    public static decimal Max(decimal a, decimal b) => Math.Max(a, b);

    // Abs
    public static double Abs(double value) => Math.Abs(value);
    public static decimal Abs(decimal value) => Math.Abs(value);

    // Pow
    public static double Pow(double a, double b) => Math.Pow(a, b);
    public static decimal Pow(decimal a, decimal b) => (decimal)Math.Pow((double)a, (double)b);

    // Log (Natural and Base)
    public static double Log(double value) => Math.Log(value);
    public static double Log(double value, double baseValue) => Math.Log(value) / Math.Log(baseValue);
    public static decimal Log(decimal value) => (decimal)Math.Log((double)value);
    public static decimal Log(decimal value, decimal baseValue) => (decimal)(Math.Log((double)value) / Math.Log((double)baseValue));

    // Exp (Exponent)
    public static double Exp(double value) => Math.Exp(value);
    public static decimal Exp(decimal value) => (decimal)Math.Exp((double)value);

    // Truncate
    public static double Truncate(double value) => Math.Truncate(value);
    public static decimal Truncate(decimal value) => Math.Truncate(value);

    // Log10 (Base 10 logarithm)
    public static double Log10(double value) => Math.Log10(value);
    public static decimal Log10(decimal value) => (decimal)Math.Log10((double)value);

    // Sqrt (Square Root)
    public static double Sqrt(double value) => Math.Sqrt(value);
    public static decimal Sqrt(decimal value) => (decimal)Math.Sqrt((double)value);

    // Sign
    public static int Sign(double value) => Math.Sign(value);
    public static int Sign(decimal value) => Math.Sign(value);

    // Ceiling
    public static double Ceiling(double value) => Math.Ceiling(value);
    public static decimal Ceiling(decimal value) => Math.Ceiling(value);

    // Floor
    public static double Floor(double value) => Math.Floor(value);
    public static decimal Floor(decimal value) => Math.Floor(value);
#else
    // Round
    public static double Round(double value, int digits) { return Math.Round(value, digits); }
    public static decimal Round(decimal value, int digits) { return Math.Round(value, digits); }

    // Min
    public static double Min(double a, double b) { return Math.Min(a, b); }
    public static decimal Min(decimal a, decimal b) { return Math.Min(a, b); }

    // Max
    public static double Max(double a, double b) { return Math.Max(a, b); }
    public static decimal Max(decimal a, decimal b) { return Math.Max(a, b); }

    // Abs
    public static double Abs(double value) { return Math.Abs(value); }
    public static decimal Abs(decimal value) { return Math.Abs(value); }

    // Pow
    public static double Pow(double a, double b) { return Math.Pow(a, b); }
    public static decimal Pow(decimal a, decimal b) { return (decimal)Math.Pow((double)a, (double)b); }

    // Log (Natural and Base)
    public static double Log(double value) { return Math.Log(value); }
    public static double Log(double value, double baseValue) { return Math.Log(value) / Math.Log(baseValue); }
    public static decimal Log(decimal value) { return (decimal)Math.Log((double)value); }
    public static decimal Log(decimal value, decimal baseValue) { return (decimal)(Math.Log((double)value) / Math.Log((double)baseValue)); }

    // Exp (Exponent)
    public static double Exp(double value) { return Math.Exp(value); }
    public static decimal Exp(decimal value) { return (decimal)Math.Exp((double)value); }

    // Truncate
    public static double Truncate(double value) { return Math.Truncate(value); }
    public static decimal Truncate(decimal value) { return Math.Truncate(value); }

    // Log10 (Base 10 logarithm)
    public static double Log10(double value) { return Math.Log10(value); }
    public static decimal Log10(decimal value) { return (decimal)Math.Log10((double)value); }

    // Sqrt (Square Root)
    public static double Sqrt(double value) { return Math.Sqrt(value); }
    public static decimal Sqrt(decimal value) { return (decimal)Math.Sqrt((double)value); }

    // Sign
    public static int Sign(double value) { return Math.Sign(value); }
    public static int Sign(decimal value) { return Math.Sign(value); }

    // Ceiling
    public static double Ceiling(double value) { return Math.Ceiling(value); }
    public static decimal Ceiling(decimal value) { return Math.Ceiling(value); }

    // Floor
    public static double Floor(double value) { return Math.Floor(value); }
    public static decimal Floor(decimal value) { return Math.Floor(value); }
#endif

private static object[] ConvertToValueTypeOrStringArray(object obj)
    {
#if NETCOREAPP3_0_OR_GREATER
        // If it's already an array, convert it manually to an object array
        if (obj is Array arr && arr.Length > 0)
        {
            object[] result = new object[arr.Length];
            for (int i = 0; i < arr.Length; i++)
                result[i] = UnwrapPSObject(arr.GetValue(i));
            return result;
        }

        // If it's a string, treat it as an array of one string
        if (obj is string str)
            return new object[] { str };

        // If it's a single ValueType, treat it as an array of one
        if (obj is ValueType)
            return new object[] { obj };

        return Array.Empty<object>(); // If not ValueType or string, return empty array
#else
        // Handle null values
        if (obj == null)
            return new object[0]; // Instead of Array.Empty<object>(), which is PS7+

        // If it's already an array, convert it manually to an object array
        Array arr = obj as Array;
        if (arr != null && arr.Length > 0)
        {
            object[] result = new object[arr.Length];
            for (int i = 0; i < arr.Length; i++)
            {
                result[i] = UnwrapPSObject(arr.GetValue(i));
            }
            return result;
        }

        // If it's a string, treat it as an array of one string
        if (obj is string)
            return new object[] { obj };

        // If it's a ValueType (like int, double, bool), treat it as an array of one
        if (obj is ValueType)
            return new object[] { obj };

        return new object[0]; // Return empty array if none of the conditions match
#endif
    }

}
