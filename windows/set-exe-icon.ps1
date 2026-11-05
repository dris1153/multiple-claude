# Replaces the icon resources of an exe in place (kernel32 UpdateResource, no external tool).
# Usage: set-exe-icon.ps1 -Exe <path> -Ico <multi-size .ico>. Throws on failure.
param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Ico)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System; using System.Collections.Generic; using System.IO; using System.Runtime.InteropServices;
public static class ExeIcon {
  delegate bool EnumName(IntPtr h, IntPtr type, IntPtr name, IntPtr lp);
  delegate bool EnumLang(IntPtr h, IntPtr type, IntPtr name, ushort lang, IntPtr lp);
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
  [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumName p, IntPtr lp);
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool EnumResourceLanguages(IntPtr h, IntPtr type, IntPtr name, EnumLang p, IntPtr lp);
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr BeginUpdateResource(string f, bool del);
  [DllImport("kernel32", SetLastError=true)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint cb);
  [DllImport("kernel32", SetLastError=true)] static extern bool EndUpdateResource(IntPtr h, bool discard);
  public static string Replace(string exe, string ico) {
    var groups = new List<KeyValuePair<IntPtr, ushort>>();
    IntPtr lib = LoadLibraryEx(exe, IntPtr.Zero, 2);
    if (lib == IntPtr.Zero) return "LoadLibraryEx failed " + Marshal.GetLastWin32Error();
    EnumResourceNames(lib, (IntPtr)14, delegate(IntPtr h, IntPtr t, IntPtr n, IntPtr lp) {
      EnumResourceLanguages(h, t, n, delegate(IntPtr h2, IntPtr t2, IntPtr n2, ushort lang, IntPtr lp2) { groups.Add(new KeyValuePair<IntPtr, ushort>(n2, lang)); return true; }, IntPtr.Zero);
      return true; }, IntPtr.Zero);
    FreeLibrary(lib);
    foreach (var g in groups) if ((long)g.Key > 0xFFFF) return "string-named group icon not supported";
    if (groups.Count == 0) return "no group icons found";
    byte[] b = File.ReadAllBytes(ico);
    int count = BitConverter.ToUInt16(b, 4);
    var grp = new MemoryStream(); var w = new BinaryWriter(grp);
    w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)count);
    IntPtr h3 = BeginUpdateResource(exe, false);
    if (h3 == IntPtr.Zero) return "BeginUpdateResource failed " + Marshal.GetLastWin32Error();
    ushort lang0 = groups[0].Value;
    for (int i = 0; i < count; i++) {
      int o = 6 + 16 * i; uint len = BitConverter.ToUInt32(b, o + 8), off = BitConverter.ToUInt32(b, o + 12);
      byte[] data = new byte[len]; Array.Copy(b, off, data, 0, len);
      ushort id = (ushort)(3000 + i);
      if (!UpdateResource(h3, (IntPtr)3, (IntPtr)id, lang0, data, len)) { EndUpdateResource(h3, true); return "UpdateResource icon failed " + Marshal.GetLastWin32Error(); }
      w.Write(b[o]); w.Write(b[o + 1]); w.Write((byte)0); w.Write((byte)0); w.Write((ushort)1); w.Write((ushort)32); w.Write(len); w.Write(id);
    }
    byte[] gd = grp.ToArray();
    foreach (var g in groups)
      if (!UpdateResource(h3, (IntPtr)14, g.Key, g.Value, gd, (uint)gd.Length)) { EndUpdateResource(h3, true); return "UpdateResource group failed " + Marshal.GetLastWin32Error(); }
    if (!EndUpdateResource(h3, false)) return "EndUpdateResource failed " + Marshal.GetLastWin32Error();
    return "OK groups=" + groups.Count + " frames=" + count;
  }
}
'@
$result = [ExeIcon]::Replace($Exe, $Ico)
if ($result -notlike 'OK*') { throw "set-exe-icon failed: $result" }
