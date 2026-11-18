# ==============================================================
#  CACAHUETE COMANDO - mascota de escritorio
#  Un cacahuete con bandana y un AK que patrulla tu escritorio.
#
#  Clic izquierdo  -> le pinchas y dispara (si le pinchas mucho: MODO LOCO)
#  Arrastrar       -> lo coges y lo tiras (desde muy alto abre paracaidas)
#  Clic derecho    -> menu: armas, trepar, minijuego, tamano, sonido,
#                     no molestar, arrancar con Windows, salir
#
#  Hecho para convivir con Hyprland4Win: ventanas de herramienta, sin
#  icono, que no roban el foco y se esconden en pantalla completa.
# ==============================================================
#  Normalmente NO se abre este archivo: "Montar cacahuete.bat" lo
#  convierte en Cacahuete.exe, que es lo que se ejecuta.
# ==============================================================
param([switch]$Build, [switch]$Silent)

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Media;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Cacahuete
{
    // ============================ Win32 ============================
    public static class Native
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT { public int x; public int y; public POINT(int a, int b) { x = a; y = b; } }
        [StructLayout(LayoutKind.Sequential)]
        public struct SIZE { public int cx; public int cy; public SIZE(int a, int b) { cx = a; cy = b; } }
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct BLENDFUNCTION { public byte BlendOp; public byte BlendFlags; public byte SourceConstantAlpha; public byte AlphaFormat; }
        [StructLayout(LayoutKind.Sequential)]
        public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }

        [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
        [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hDC);
        [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
        [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
        [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr hObject);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref POINT pptDst, ref SIZE psize,
            IntPtr hdcSrc, ref POINT pprSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
        [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
        [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

        // Pixeles reales en todas las pantallas aunque tengan distinta escala
        public static void MakeDpiAware()
        {
            try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch { }
            try { SetProcessDPIAware(); } catch { }
        }
        [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

        [StructLayout(LayoutKind.Sequential)]
        public struct BITMAPINFOHEADER
        {
            public uint biSize; public int biWidth; public int biHeight; public ushort biPlanes; public ushort biBitCount;
            public uint biCompression; public uint biSizeImage; public int biXPelsPerMeter; public int biYPelsPerMeter;
            public uint biClrUsed; public uint biClrImportant;
        }
        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateDIBSection(IntPtr hdc, ref BITMAPINFOHEADER bmi, uint usage, out IntPtr bits, IntPtr hSection, uint offset);

        public static string ProcessOf(IntPtr h)
        {
            try
            {
                uint pid; GetWindowThreadProcessId(h, out pid);
                if (pid == 0) return "";
                using (System.Diagnostics.Process p = System.Diagnostics.Process.GetProcessById((int)pid)) return p.ProcessName.ToLowerInvariant();
            }
            catch { return ""; }
        }

        public static bool Blit(IntPtr handle, Bitmap bmp, int left, int top)
        {
            IntPtr screenDc = GetDC(IntPtr.Zero);
            IntPtr memDc = CreateCompatibleDC(screenDc);
            IntPtr hBmp = IntPtr.Zero, old = IntPtr.Zero;
            bool ok = false;
            try
            {
                hBmp = bmp.GetHbitmap(Color.FromArgb(0));
                old = SelectObject(memDc, hBmp);
                SIZE size = new SIZE(bmp.Width, bmp.Height);
                POINT src = new POINT(0, 0);
                POINT dst = new POINT(left, top);
                BLENDFUNCTION bf = new BLENDFUNCTION();
                bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;
                ok = UpdateLayeredWindow(handle, screenDc, ref dst, ref size, memDc, ref src, 0, ref bf, 2);
            }
            finally
            {
                ReleaseDC(IntPtr.Zero, screenDc);
                if (hBmp != IntPtr.Zero) { SelectObject(memDc, old); DeleteObject(hBmp); }
                DeleteDC(memDc);
            }
            return ok;
        }

        public static uint IdleMs()
        {
            LASTINPUTINFO li = new LASTINPUTINFO();
            li.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
            if (!GetLastInputInfo(ref li)) return 0;
            return (uint)Environment.TickCount - li.dwTime;
        }

        public static string ClassOf(IntPtr h) { StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }
        public static string TitleOf(IntPtr h) { StringBuilder sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
    }

    // Suelo con varias pantallas: la pantalla que hay debajo de x cuyo borde inferior
    // esta a la altura de los pies o por debajo. Si todas quedan por encima, devuelve la mas baja
    // de ellas (es un escalon hacia arriba).
    public static class Floors
    {
        public static Screen At(float x, float y, float tol)
        {
            Screen best = null, highest = null;
            foreach (Screen s in Screen.AllScreens)
            {
                Rectangle b = s.Bounds;
                if (x < b.Left || x >= b.Right) continue;
                if (b.Bottom >= y - tol) { if (best == null || b.Bottom < best.Bounds.Bottom) best = s; }
                else if (highest == null || b.Bottom > highest.Bounds.Bottom) highest = s;
            }
            if (best != null) return best;
            if (highest != null) return highest;
            return Screen.FromPoint(new Point((int)x, (int)y));
        }
    }

    // Lienzo persistente (DIB premultiplicado): se reutiliza en cada fotograma, sin crear bitmaps nuevos.
    public class Surface : IDisposable
    {
        public int W, H;
        public Bitmap Bmp;
        IntPtr memDc, hBmp, old;

        public void Ensure(int w, int h)
        {
            w = Math.Max(1, w); h = Math.Max(1, h);
            if (Bmp != null && w <= W && h <= H) return;
            Dispose();
            W = w; H = h;
            Native.BITMAPINFOHEADER bi = new Native.BITMAPINFOHEADER();
            bi.biSize = (uint)Marshal.SizeOf(typeof(Native.BITMAPINFOHEADER));
            bi.biWidth = W; bi.biHeight = -H; bi.biPlanes = 1; bi.biBitCount = 32;
            IntPtr screen = Native.GetDC(IntPtr.Zero);
            memDc = Native.CreateCompatibleDC(screen);
            Native.ReleaseDC(IntPtr.Zero, screen);
            IntPtr bits;
            hBmp = Native.CreateDIBSection(memDc, ref bi, 0, out bits, IntPtr.Zero, 0);
            old = Native.SelectObject(memDc, hBmp);
            Bmp = new Bitmap(W, H, W * 4, PixelFormat.Format32bppPArgb, bits);
        }

        public Graphics Begin(int w, int h)
        {
            Ensure(w, h);
            Graphics g = Graphics.FromImage(Bmp);
            g.SetClip(new Rectangle(0, 0, w, h));
            g.Clear(Color.Transparent);
            g.ResetClip();
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            return g;
        }

        // Limpia solo el trozo que se va a usar (el resto del lienzo no se envia)
        public Graphics BeginRegion(int w, int h, Rectangle r)
        {
            Ensure(w, h);
            Graphics g = Graphics.FromImage(Bmp);
            g.SetClip(r);
            g.Clear(Color.Transparent);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            return g;
        }

        public bool PresentRegion(IntPtr hwnd, int left, int top, Rectangle r)
        {
            Native.SIZE size = new Native.SIZE(r.Width, r.Height);
            Native.POINT src = new Native.POINT(r.X, r.Y);
            Native.POINT dst = new Native.POINT(left + r.X, top + r.Y);
            Native.BLENDFUNCTION bf = new Native.BLENDFUNCTION();
            bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;
            return Native.UpdateLayeredWindow(hwnd, IntPtr.Zero, ref dst, ref size, memDc, ref src, 0, ref bf, 2);
        }

        public IntPtr MemDc { get { return memDc; } }

        public bool Present(IntPtr hwnd, int left, int top, int w, int h)
        {
            Native.SIZE size = new Native.SIZE(w, h);
            Native.POINT src = new Native.POINT(0, 0);
            Native.POINT dst = new Native.POINT(left, top);
            Native.BLENDFUNCTION bf = new Native.BLENDFUNCTION();
            bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;
            return Native.UpdateLayeredWindow(hwnd, IntPtr.Zero, ref dst, ref size, memDc, ref src, 0, ref bf, 2);
        }

        public void Dispose()
        {
            if (Bmp != null) { Bmp.Dispose(); Bmp = null; }
            if (memDc != IntPtr.Zero)
            {
                Native.SelectObject(memDc, old);
                if (hBmp != IntPtr.Zero) Native.DeleteObject(hBmp);
                Native.DeleteDC(memDc);
            }
            memDc = IntPtr.Zero; hBmp = IntPtr.Zero;
        }
    }

    // ===================== medidor de audio (musica) =====================
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorCom { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    }

    [ComImport, Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioMeterInformation
    {
        [PreserveSig] int GetPeakValue(out float peak);
    }

    public class AudioMeter
    {
        IAudioMeterInformation meter;
        public bool Init()
        {
            meter = null;
            try
            {
                IMMDeviceEnumerator en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom());
                IMMDevice dev;
                if (en.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return false;
                Guid iid = typeof(IAudioMeterInformation).GUID;
                object o;
                if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0 || o == null) return false;
                meter = (IAudioMeterInformation)o;
                return true;
            }
            catch (Exception ex) { Log.W("audio no disponible: " + ex.Message); return false; }
        }
        public float Peak()
        {
            if (meter == null) return 0;
            try { float p; if (meter.GetPeakValue(out p) == 0) return p; }
            catch { meter = null; }
            return 0;
        }
    }

    // ============================ utilidades ============================
    public static class Log
    {
        public static string Path;
        public static void W(string msg)
        {
            try { if (Path != null) File.AppendAllText(Path, DateTime.Now.ToString("HH:mm:ss.fff") + "  " + msg + "\r\n"); } catch { }
        }
    }

    public static class Settings
    {
        const string KEY = @"Software\CacahueteComando";
        public static string Get(string name, string def)
        {
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(KEY))
                {
                    if (k == null) return def;
                    object v = k.GetValue(name);
                    return v == null ? def : v.ToString();
                }
            }
            catch { return def; }
        }
        public static void Set(string name, string val)
        {
            try { using (RegistryKey k = Registry.CurrentUser.CreateSubKey(KEY)) k.SetValue(name, val); } catch { }
        }
        public static float GetF(string name, float def)
        {
            float f;
            if (float.TryParse(Get(name, ""), NumberStyles.Float, CultureInfo.InvariantCulture, out f)) return f;
            return def;
        }
        public static void SetF(string name, float v) { Set(name, v.ToString(CultureInfo.InvariantCulture)); }
    }

    // ============================ objetos del mundo ============================
    public class Bullet { public float X, Y, PX, PY, VX, VY, Dist, StopDist; public bool Game; }
    public class Hole { public float X, Y, Life; public float[] Ang; public float[] Len; }
    public class Part { public int Kind; public float X, Y, VX, VY, Rot, VR, Life, Size, Phase; public Color Col; public bool Grounded; }
    public class Ring { public float X, Y, MaxR, Life, MaxLife; }
    public class Popup { public float X, Y, Life, MaxLife; public string Text; public Color Col; }
    public class Splat { public float X, Y, Life, MaxLife; public float[] BX, BY, BR, DX, DL; }
    public class Blob { public float X, Y, VX, VY, Dist, StopDist; }
    public class Grenade { public float X, Y, VX, VY, Rot, VR, Fuse; }

    public enum PetState { Idle, Walk, Shoot, Drag, Fall, Sleep, Dance, Crazy, Reload, Climb, Squats, Bazooka, Throw, Confetti, Guard, Dodge, MusicDance, Trench }
    public enum Orient { Floor, Ceiling, WallLeft, WallRight }
    public enum Surf { Ground, WindowTop, Ceiling }
    public enum Weapon { AK, Bazooka, Confetti }
    public enum Goal { None, ClimbWindow, ClimbCeiling, Travel, Trench }

    // Capa transparente a pantalla completa para balas y efectos. Los clics la atraviesan.
    public class OverlayForm : Form
    {
        Surface surf = new Surface();
        bool empty;
        public Rectangle Area;
        public float OX, OY;   // esquina del trozo que se esta dibujando

        public OverlayForm()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;
            Text = "Cacahuete Efectos";
            Area = SystemInformation.VirtualScreen;
            Bounds = Area;
        }

        // cuando conectas/desconectas pantallas
        public void Reset()
        {
            Area = SystemInformation.VirtualScreen;
            Bounds = Area;
            surf.Dispose(); surf = new Surface();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x00080000 | 0x00000080 | 0x00000008 | 0x08000000 | 0x00000020; // LAYERED|TOOLWINDOW|TOPMOST|NOACTIVATE|TRANSPARENT
                return cp;
            }
        }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0021) { m.Result = (IntPtr)3; return; }
            base.WndProc(ref m);
        }

        // Dibuja solo el rectangulo que ocupan los efectos (no la pantalla entera)
        public void Draw(Rectangle box, Action<Graphics> painter)
        {
            box.Intersect(Area);
            if (box.Width <= 0 || box.Height <= 0) { Clear(); return; }
            OX = box.Left; OY = box.Top;
            using (Graphics g = surf.Begin(box.Width, box.Height)) painter(g);
            surf.Present(Handle, box.Left, box.Top, box.Width, box.Height);
            empty = false;
        }

        public void Clear()
        {
            if (empty) return;
            using (Graphics g = surf.Begin(1, 1)) { }
            surf.Present(Handle, Area.Left, Area.Top, 1, 1);
            empty = true;
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            surf.Dispose();
            base.OnFormClosed(e);
        }
    }

    // ============================ graficos realistas (imagenes) ============================
    // Imagenes en la carpeta "sprites": 2 pixeles por unidad, ancla abajo en el centro (los pies).
    public class SpriteSet : IDisposable
    {
        Dictionary<string, Bitmap> frames = new Dictionary<string, Bitmap>();
        static readonly string[] NAMES = { "idle", "walk1", "walk2", "sleep", "fall", "dance", "crazy" };

        public static SpriteSet Load(string dir)
        {
            try
            {
                if (!File.Exists(System.IO.Path.Combine(dir, "idle.png"))) return null;
                SpriteSet set = new SpriteSet();
                foreach (string n in NAMES)
                {
                    string f = System.IO.Path.Combine(dir, n + ".png");
                    if (!File.Exists(f)) continue;
                    using (FileStream fs = File.OpenRead(f))
                    using (Bitmap tmp = new Bitmap(fs))
                    {
                        Bitmap b = new Bitmap(tmp.Width, tmp.Height, PixelFormat.Format32bppPArgb);
                        using (Graphics g = Graphics.FromImage(b)) g.DrawImage(tmp, 0, 0, tmp.Width, tmp.Height);
                        set.frames[n] = b;
                    }
                }
                Log.W("sprites cargados: " + set.frames.Count);
                return set;
            }
            catch (Exception ex) { Log.W("ERROR cargando sprites: " + ex.Message); return null; }
        }

        public Bitmap Get(string n)
        {
            Bitmap b;
            if (frames.TryGetValue(n, out b)) return b;
            return frames["idle"];
        }

        // boca del canon de cada postura (unidades del cacahuete, mirando a la derecha, pies en 0,0)
        public static PointF Muzzle(string n)
        {
            if (n == "walk1" || n == "walk2") return new PointF(68f, -81.5f);
            if (n == "crazy") return new PointF(67.5f, -83.8f);
            return new PointF(96.5f, -89.4f);
        }

        public void Dispose()
        {
            foreach (Bitmap b in frames.Values) b.Dispose();
            frames.Clear();
        }
    }

    // Las mascotas no cogen el foco, asi que Windows no cierra solo sus menus al hacer clic fuera.
    // Esto los vigila: clic fuera o Esc -> se cierran.
    public static class MenuWatch
    {
        public static void Watch(ContextMenuStrip m)
        {
            System.Windows.Forms.Timer w = new System.Windows.Forms.Timer();
            w.Interval = 40;
            bool wasDown = Control.MouseButtons != MouseButtons.None;
            w.Tick += delegate
            {
                if (!m.Visible) { w.Stop(); w.Dispose(); return; }
                bool down = Control.MouseButtons != MouseButtons.None;
                if (down && !wasDown && !InMenu(m, Cursor.Position)) m.Close(ToolStripDropDownCloseReason.AppClicked);
                else if ((Native.GetAsyncKeyState(0x1B) & 0x8000) != 0) m.Close(ToolStripDropDownCloseReason.Keyboard);
                wasDown = down;
            };
            w.Start();
        }

        static bool InMenu(ToolStripDropDown dd, Point p)
        {
            if (dd.Visible && dd.Bounds.Contains(p)) return true;
            foreach (ToolStripItem it in dd.Items)
            {
                ToolStripMenuItem mi = it as ToolStripMenuItem;
                if (mi != null && mi.HasDropDownItems && mi.DropDown.Visible && InMenu(mi.DropDown, p)) return true;
            }
            return false;
        }
    }

    // Ventanita para pedir un texto y/o unos minutos
    public class AskForm : Form
    {
        public TextBox Box;
        public NumericUpDown Mins;

        public AskForm(string title, string label, bool wantText, bool wantMinutes, int defMinutes)
        {
            Text = title;
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Segoe UI", 10f);
            TopMost = true; ShowInTaskbar = false; MaximizeBox = false; MinimizeBox = false;
            ClientSize = new Size(400, wantText && wantMinutes ? 170 : 130);
            int y = 14;
            Label l = new Label(); l.Text = label; l.AutoSize = true; l.Location = new Point(14, y); Controls.Add(l);
            y += 28;
            if (wantText)
            {
                Box = new TextBox(); Box.SetBounds(14, y, 370, 28); Controls.Add(Box); y += 40;
            }
            if (wantMinutes)
            {
                Label lm = new Label(); lm.Text = "Dentro de (minutos):"; lm.AutoSize = true; lm.Location = new Point(14, y + 3); Controls.Add(lm);
                Mins = new NumericUpDown(); Mins.Minimum = 1; Mins.Maximum = 1440; Mins.Value = defMinutes;
                Mins.SetBounds(180, y, 80, 28); Controls.Add(Mins); y += 40;
            }
            Button ok = new Button(); ok.Text = "Vale"; ok.DialogResult = DialogResult.OK; ok.SetBounds(214, ClientSize.Height - 42, 80, 30);
            Button cancel = new Button(); cancel.Text = "Cancelar"; cancel.DialogResult = DialogResult.Cancel; cancel.SetBounds(302, ClientSize.Height - 42, 84, 30);
            Controls.Add(ok); Controls.Add(cancel);
            AcceptButton = ok; CancelButton = cancel;
            Shown += delegate { Activate(); if (Box != null) Box.Focus(); else if (Mins != null) Mins.Focus(); };
        }

        protected override CreateParams CreateParams
        {
            get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x00000080; return cp; }
        }
    }

    // ============================ diario de guerra ============================
    public class Diary
    {
        const string KEY = @"Software\CacahueteComando\Diario";
        public string Date;
        public int Shots, Pokes, Crazy;
        public float Active;

        static string Today() { return DateTime.Now.ToString("yyyy-MM-dd"); }

        static void Read(string d, out int sh, out int po, out int cr, out float ac)
        {
            sh = 0; po = 0; cr = 0; ac = 0;
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(KEY + "\\" + d))
                {
                    if (k == null) return;
                    sh = Convert.ToInt32(k.GetValue("Shots", 0));
                    po = Convert.ToInt32(k.GetValue("Pokes", 0));
                    cr = Convert.ToInt32(k.GetValue("Crazy", 0));
                    ac = Convert.ToInt32(k.GetValue("Active", 0));
                }
            }
            catch { }
        }

        public void Load() { Date = Today(); Read(Date, out Shots, out Pokes, out Crazy, out Active); }

        public void Save()
        {
            try
            {
                using (RegistryKey k = Registry.CurrentUser.CreateSubKey(KEY + "\\" + Date))
                {
                    k.SetValue("Shots", Shots, RegistryValueKind.DWord);
                    k.SetValue("Pokes", Pokes, RegistryValueKind.DWord);
                    k.SetValue("Crazy", Crazy, RegistryValueKind.DWord);
                    k.SetValue("Active", (int)Active, RegistryValueKind.DWord);
                }
            }
            catch { }
        }

        public void Roll()
        {
            if (Date == Today()) return;
            Save();
            Date = Today(); Shots = 0; Pokes = 0; Crazy = 0; Active = 0;
        }

        static string Time(float secs)
        {
            int m = (int)(secs / 60);
            return m >= 60 ? (m / 60) + " h " + (m % 60) + " min" : m + " min";
        }

        static string Line(int sh, int po, int cr, float ac)
        {
            return sh + " balas, " + po + (po == 1 ? " pinchazo, " : " pinchazos, ") + cr +
                   (cr == 1 ? " ataque de locura" : " ataques de locura") + " y " + Time(ac) + " de PC";
        }

        public string Summary() { return "Diario de guerra de hoy: " + Line(Shots, Pokes, Crazy, Active) + "."; }

        public string History(int days)
        {
            Save();
            CultureInfo es = new CultureInfo("es-ES");
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("DIARIO DE GUERRA DEL CACAHUETE COMANDO");
            sb.AppendLine();
            for (int i = 0; i < days; i++)
            {
                DateTime d = DateTime.Now.AddDays(-i);
                int sh, po, cr; float ac;
                Read(d.ToString("yyyy-MM-dd"), out sh, out po, out cr, out ac);
                string name = i == 0 ? "Hoy" : (i == 1 ? "Ayer" : d.ToString("dddd d 'de' MMMM", es));
                sb.AppendLine(name + ":");
                sb.AppendLine("   " + (sh + po + cr + ac > 0 ? Line(sh, po, cr, ac) : "sin actividad"));
                sb.AppendLine();
            }
            return sb.ToString();
        }
    }

    // ============================ PIPO, el recluta pipa ============================
    public class BuddyForm : Form
    {
        public static readonly string[][] DIALOGS = {
            new string[] { "Pipo, informe de situación.", "Todo tranquilo, mi sargento. Bueno, menos usted." },
            new string[] { "¿Por qué siempre me sigues?", "Porque solo no me como ni una pipa. Literal." },
            new string[] { "¿Has visto al enemigo?", "Solo una almendra con gafas de sol. Muy sospechosa." },
            new string[] { "Pipo, ponte firme.", "Estoy firme. Es que soy así de bajito." },
            new string[] { "Algún día seré general.", "Y yo su secretario. Con sueldo, espero." },
            new string[] { "¿Tienes miedo, recluta?", "¿Yo? Qué va. Tiemblo por el frío." },
            new string[] { "Hoy toca entrenamiento duro.", "¿Duro como una cáscara o como una pipa?" },
            new string[] { "Pipo, ¿dónde está tu arma?", "La dejé en el otro escritorio. Muy lejos. Qué pena." },
            new string[] { "Somos la élite de los frutos secos.", "Yo técnicamente soy una semilla, pero vale." },
        };
        static readonly string[] POKE = { "¡Eh, que soy pequeño!", "Soy Pipo, recluta de primera... bueno, de última.",
            "No me pinches, que me desgrano.", "El sargento es el otro. Yo solo le sigo.", "¿Tienes sal? Es para un amigo." };
        static readonly string[] FLEE = { "¡Está loco otra vez!", "¡Sálvese quien pueda!", "¡Yo no he sido!", "¡A cubierto, que dispara!" };
        static readonly string[] WAIT = { "¡Mi sargento, baje de ahí!", "Yo le espero aquí abajo, ¿eh?", "¡Qué vértigo solo de mirarle!" };
        static readonly string[] EARS = { "¡Mis oídos!", "¿Hace falta tanto ruido?", "¡Avise antes, hombre!" };

        enum BState { Follow, Flee, Fall, Drag, Sleep }

        const int LW = 360, LH = 260;
        const float FX = 180f, FY = 240f;

        PetForm pet;
        Surface surf = new Surface();
        Random rnd = new Random();
        BState st = BState.Fall;
        float bx, by, vx, vy, t, stateTime, walkPhase, blinkTimer = 2f, blinkLeft, squash, waitTalk = 8f, sleepWait;
        int facing = 1, tick;
        bool walking, mouseDown, dragging;
        int downX, downY; float offX, offY;
        string speech, lastDrawn; float speechLeft;
        PetState lastPetState;

        // ---- Pipo, el secretario ----
        ContextMenuStrip pmenu;
        ToolStripMenuItem clipMenu, remMenu, stopTimerItem;
        float timerLeft = -1, timerTotal, alarmLeft, clipPoll, remPoll, hopTimer;
        string timerLabel = "";
        bool pomodoro, pomoWork; int pomoCount;
        uint clipSeq;
        List<string> clips = new List<string>();
        class Reminder { public DateTime When; public string Text; }
        List<Reminder> reminders = new List<Reminder>();
        string Dir { get { return System.IO.Path.GetDirectoryName(AutoStart.ScriptPath); } }

        public BuddyForm(PetForm p)
        {
            pet = p;
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;
            Text = "Pipo";
            bx = pet.PetX - 150 * pet.PetScale; by = pet.PetY - 300 * pet.PetScale; vy = 0;
            Say("¡Recluta Pipo, presentándose! Haz clic en mí si necesitas algo.", 3.5f);
            BuildMenu();
            LoadReminders();
            try { clipSeq = Native.GetClipboardSequenceNumber(); } catch { }
        }

        // =========================== menu de Pipo ===========================
        void BuildMenu()
        {
            pmenu = new ContextMenuStrip();

            ToolStripMenuItem tm = new ToolStripMenuItem("Temporizador");
            foreach (int m in new int[] { 1, 5, 10, 15, 25, 45, 60 })
            {
                int mm = m;
                tm.DropDownItems.Add(m + (m == 1 ? " minuto" : " minutos"), null, delegate { StartTimer(mm * 60f, mm + " min", false); });
            }
            tm.DropDownItems.Add("Otro...", null, delegate
            {
                using (AskForm f = new AskForm("Temporizador", "¿Cuánto tiempo cuento?", false, true, 20))
                    if (f.ShowDialog() == DialogResult.OK) StartTimer((float)f.Mins.Value * 60f, f.Mins.Value + " min", false);
            });
            pmenu.Items.Add(tm);

            pmenu.Items.Add("Pomodoro (25 trabajo / 5 descanso)", null, delegate { StartPomodoro(); });
            stopTimerItem = new ToolStripMenuItem("Parar temporizador", null, delegate { StopTimer(true); });
            pmenu.Items.Add(stopTimerItem);
            pmenu.Items.Add(new ToolStripSeparator());

            pmenu.Items.Add("Recuérdame algo...", null, delegate { AskReminder(); });
            remMenu = new ToolStripMenuItem("Recordatorios pendientes");
            pmenu.Items.Add(remMenu);
            pmenu.Items.Add(new ToolStripSeparator());

            pmenu.Items.Add("Nota rápida...", null, delegate { AskNote(); });
            pmenu.Items.Add("Ver mis notas", null, delegate { OpenNotes(); });
            clipMenu = new ToolStripMenuItem("Lo último que copiaste");
            pmenu.Items.Add(clipMenu);
            pmenu.Items.Add(new ToolStripSeparator());

            pmenu.Items.Add("¿Qué hora es?", null, delegate { SayTime(); });
            pmenu.Items.Add("¿Cómo va la batería?", null, delegate { SayBattery(); });
            pmenu.Items.Add("Cuéntame algo", null, delegate { Say(Pick(POKE), 3f); });
            pmenu.Items.Add(new ToolStripSeparator());
            pmenu.Items.Add("Menú del Cacahuete", null, delegate { pet.ShowMenu(); });

            pmenu.Opening += delegate
            {
                stopTimerItem.Enabled = timerLeft > 0 || pomodoro;
                stopTimerItem.Text = pomodoro ? "Parar pomodoro" : "Parar temporizador";

                clipMenu.DropDownItems.Clear();
                if (clips.Count == 0) { ToolStripMenuItem e0 = new ToolStripMenuItem("(nada todavía)"); e0.Enabled = false; clipMenu.DropDownItems.Add(e0); }
                foreach (string c in clips)
                {
                    string text = c;
                    string label = text.Replace("\r", " ").Replace("\n", " ").Trim();
                    if (label.Length > 45) label = label.Substring(0, 45) + "…";
                    clipMenu.DropDownItems.Add(label, null, delegate
                    {
                        try { Clipboard.SetText(text); clipSeq = Native.GetClipboardSequenceNumber(); Say("Copiado otra vez. De nada.", 2f); } catch { }
                    });
                }

                remMenu.DropDownItems.Clear();
                if (reminders.Count == 0) { ToolStripMenuItem e1 = new ToolStripMenuItem("(ninguno)"); e1.Enabled = false; remMenu.DropDownItems.Add(e1); }
                foreach (Reminder r in reminders)
                {
                    Reminder rr = r;
                    string when = r.When.Date == DateTime.Today ? r.When.ToString("HH:mm") : r.When.ToString("dd/MM HH:mm");
                    remMenu.DropDownItems.Add(when + " · " + r.Text + "  (clic para borrar)", null, delegate
                    {
                        reminders.Remove(rr); SaveReminders(); Say("Recordatorio borrado.", 2f);
                    });
                }
            };
            pmenu.Opened += delegate { MenuWatch.Watch(pmenu); };
        }

        void StartTimer(float secs, string label, bool pomo)
        {
            timerLeft = secs; timerTotal = secs; timerLabel = label; alarmLeft = 0;
            if (!pomo) { pomodoro = false; pet.PomodoroFocus = false; }
            Say(pomo ? (pomoWork ? "¡A currar! 25 minutos. El sargento no molestará." : "Descanso de 5 minutos. ¡Estira!") : "Cuento " + label + ". Yo aviso.", 3f);
        }

        void StartPomodoro()
        {
            pomodoro = true; pomoWork = true; pomoCount = 0;
            pet.PomodoroFocus = true;
            StartTimer(25 * 60f, "Trabajo", true);
        }

        void StopTimer(bool talk)
        {
            timerLeft = -1; pomodoro = false; pet.PomodoroFocus = false; alarmLeft = 0;
            if (talk) Say("Temporizador parado.", 2f);
        }

        void TimerDone()
        {
            if (pomodoro)
            {
                if (pomoWork)
                {
                    pomoCount++;
                    pomoWork = false; pet.PomodoroFocus = false;
                    StartTimer(5 * 60f, "Descanso", true);
                    Alarm("¡Pomodoro " + pomoCount + " terminado! Descanso de 5 minutos.");
                }
                else
                {
                    pomoWork = true; pet.PomodoroFocus = true;
                    StartTimer(25 * 60f, "Trabajo", true);
                    Alarm("Se acabó el descanso. ¡Otro pomodoro!");
                }
                return;
            }
            timerLeft = -1;
            Alarm("¡RIIIING! ¡Tiempo! (" + timerLabel + ")");
        }

        void Alarm(string text)
        {
            alarmLeft = 6f; hopTimer = 0;
            Say(text, 10f);
            try { System.Media.SystemSounds.Exclamation.Play(); } catch { }
        }

        void AskReminder()
        {
            using (AskForm f = new AskForm("Recordatorio", "¿Qué te recuerdo?", true, true, 30))
            {
                if (f.ShowDialog() != DialogResult.OK || f.Box.Text.Trim().Length == 0) return;
                Reminder r = new Reminder();
                r.When = DateTime.Now.AddMinutes((double)f.Mins.Value); r.Text = f.Box.Text.Trim().Replace("|", "/");
                reminders.Add(r);
                reminders.Sort(delegate(Reminder a, Reminder b) { return a.When.CompareTo(b.When); });
                SaveReminders();
                Say("Apuntado. A las " + r.When.ToString("HH:mm") + " te lo digo.", 3f);
            }
        }

        string RemFile { get { return System.IO.Path.Combine(Dir, "recordatorios.txt"); } }

        void LoadReminders()
        {
            try
            {
                if (!File.Exists(RemFile)) return;
                foreach (string line in File.ReadAllLines(RemFile, Encoding.UTF8))
                {
                    int i = line.IndexOf('|');
                    if (i <= 0) continue;
                    DateTime w;
                    if (!DateTime.TryParseExact(line.Substring(0, i), "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out w)) continue;
                    Reminder r = new Reminder(); r.When = w; r.Text = line.Substring(i + 1);
                    reminders.Add(r);
                }
                reminders.Sort(delegate(Reminder a, Reminder b) { return a.When.CompareTo(b.When); });
            }
            catch (Exception ex) { Log.W("recordatorios: " + ex.Message); }
        }

        void SaveReminders()
        {
            try
            {
                List<string> lines = new List<string>();
                foreach (Reminder r in reminders) lines.Add(r.When.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) + "|" + r.Text);
                File.WriteAllLines(RemFile, lines.ToArray(), Encoding.UTF8);
            }
            catch (Exception ex) { Log.W("recordatorios: " + ex.Message); }
        }

        string NotesFile { get { return System.IO.Path.Combine(Dir, "notas.txt"); } }

        void AskNote()
        {
            using (AskForm f = new AskForm("Nota rápida", "Escribe la nota:", true, false, 0))
            {
                if (f.ShowDialog() != DialogResult.OK || f.Box.Text.Trim().Length == 0) return;
                try
                {
                    File.AppendAllText(NotesFile, DateTime.Now.ToString("dd/MM/yyyy HH:mm") + "  " + f.Box.Text.Trim() + "\r\n", Encoding.UTF8);
                    Say("Nota guardada en notas.txt.", 2.5f);
                }
                catch { Say("No he podido guardar la nota.", 2.5f); }
            }
        }

        void OpenNotes()
        {
            try
            {
                if (!File.Exists(NotesFile)) File.WriteAllText(NotesFile, "", Encoding.UTF8);
                System.Diagnostics.Process.Start("notepad.exe", "\"" + NotesFile + "\"");
            }
            catch { Say("No encuentro el bloc de notas.", 2.5f); }
        }

        void SayTime()
        {
            CultureInfo es = new CultureInfo("es-ES");
            Say("Son las " + DateTime.Now.ToString("HH:mm") + ". Hoy es " + DateTime.Now.ToString("dddd d 'de' MMMM", es) + ".", 4f);
        }

        void SayBattery()
        {
            try
            {
                PowerStatus ps = SystemInformation.PowerStatus;
                if (ps.BatteryChargeStatus == BatteryChargeStatus.NoSystemBattery) { Say("Este ordenador no tiene batería. Vive enchufado, como yo a las pipas.", 3.5f); return; }
                int pct = (int)Math.Round(ps.BatteryLifePercent * 100);
                bool plugged = ps.PowerLineStatus == PowerLineStatus.Online;
                Say("Batería al " + pct + " %" + (plugged ? ", y cargando." : (pct < 20 ? ". ¡Enchúfalo ya!" : ".")), 3.5f);
            }
            catch { Say("No consigo leer la batería.", 2.5f); }
        }

        void PollClipboard()
        {
            try
            {
                uint seq = Native.GetClipboardSequenceNumber();
                if (seq == clipSeq) return;
                clipSeq = seq;
                if (!Clipboard.ContainsText()) return;
                string txt = Clipboard.GetText();
                if (string.IsNullOrEmpty(txt) || txt.Trim().Length == 0 || txt.Length > 20000) return;
                clips.Remove(txt);
                clips.Insert(0, txt);
                if (clips.Count > 10) clips.RemoveAt(clips.Count - 1);
            }
            catch { }
        }

        void StepTools(float dt)
        {
            if (timerLeft > 0)
            {
                timerLeft -= dt;
                if (timerLeft <= 0) TimerDone();
            }
            if (alarmLeft > 0) alarmLeft -= dt;

            clipPoll -= dt;
            if (clipPoll <= 0) { clipPoll = 1f; PollClipboard(); }

            remPoll -= dt;
            if (remPoll <= 0 && reminders.Count > 0)
            {
                remPoll = 2f;
                if (reminders[0].When <= DateTime.Now)
                {
                    Reminder r = reminders[0];
                    reminders.RemoveAt(0); SaveReminders();
                    Alarm("¡Recordatorio! " + r.Text);
                }
            }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x00080000 | 0x00000080 | 0x00000008 | 0x08000000;
                return cp;
            }
        }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0021) { m.Result = (IntPtr)3; return; }
            base.WndProc(ref m);
        }

        static readonly Font PIPO_FONT = new Font("Segoe UI", 13f, FontStyle.Bold, GraphicsUnit.Pixel);
        static readonly Font PIPO_TIMER_FONT = new Font("Segoe UI", 12f, FontStyle.Bold, GraphicsUnit.Pixel);

        public bool CanTalk { get { return st == BState.Follow && speech == null; } }
        public void Say(string s, float secs) { speech = s; speechLeft = secs; }
        public void Drop() { if (st != BState.Drag) { st = BState.Fall; stateTime = 0; } }
        string Pick(string[] a) { return a[rnd.Next(a.Length)]; }

        public void Tick(float dt)
        {
            float S = pet.PetScale;
            t += dt; tick++; stateTime += dt;
            StepTools(dt);
            if (speechLeft > 0) { speechLeft -= dt; if (speechLeft <= 0) speech = null; }
            blinkTimer -= dt;
            if (blinkTimer <= 0) { blinkLeft = 0.12f; blinkTimer = 2f + (float)rnd.NextDouble() * 3f; }
            if (blinkLeft > 0) blinkLeft -= dt;
            squash = Math.Max(0, squash - dt * 5f);

            Screen scr = Floors.At(bx, by, 20 * S);
            float ground = scr.Bounds.Bottom - 2 * S;
            Rectangle vs = SystemInformation.VirtualScreen;
            PetState ps = pet.PetStateNow;
            walking = false;

            switch (st)
            {
                case BState.Drag:
                    {
                        Point c = Cursor.Position;
                        float nx = c.X - offX, ny = c.Y - offY;
                        vx = vx * 0.6f + (nx - bx) / Math.Max(dt, 0.001f) * 0.4f;
                        vy = vy * 0.6f + (ny - by) / Math.Max(dt, 0.001f) * 0.4f;
                        bx = nx; by = Math.Min(ny, ground);
                        if ((Control.MouseButtons & MouseButtons.Left) == 0) { st = BState.Fall; stateTime = 0; mouseDown = false; dragging = false; }
                    }
                    break;

                case BState.Fall:
                    vy += 1900f * S * dt; vx *= (1f - 0.8f * dt);
                    bx += vx * dt; by += vy * dt;
                    if (bx < vs.Left + 20 * S) { bx = vs.Left + 20 * S; vx = Math.Abs(vx) * 0.5f; }
                    if (bx > vs.Right - 20 * S) { bx = vs.Right - 20 * S; vx = -Math.Abs(vx) * 0.5f; }
                    if (by >= ground)
                    {
                        by = ground;
                        squash = Math.Min(1f, vy / (1200f * S));
                        if (vy > 900f * S) Say("¡Ay! ¡Que soy de cáscara fina!", 2f);
                        vx = 0; vy = 0; st = BState.Follow; stateTime = 0;
                    }
                    break;

                case BState.Sleep:
                    by = ground;
                    if (ps != PetState.Sleep) { st = BState.Follow; stateTime = 0; if (rnd.NextDouble() < 0.5) Say("¡Estoy despierto! ¡Estoy despierto!", 2f); }
                    break;

                case BState.Flee:
                    {
                        if (ground > by + 12 * S) { st = BState.Fall; stateTime = 0; break; }
                        by = ground;
                        float away = bx < pet.PetX ? -1 : 1;
                        if (bx < vs.Left + 80 * S) away = 1; else if (bx > vs.Right - 80 * S) away = -1;
                        if (Math.Abs(bx - pet.PetX) < 650 * S)
                        {
                            bx += away * 260f * S * dt; facing = (int)away; walking = true; walkPhase += dt * 18f;
                        }
                        else facing = bx < pet.PetX ? 1 : -1;
                        if (ps != PetState.Crazy && ps != PetState.Dodge && stateTime > 1.5f) { st = BState.Follow; stateTime = 0; Say("Uf... ¿ya pasó?", 2f); }
                    }
                    break;

                default:
                    {
                        if (ground > by + 12 * S) { st = BState.Fall; stateTime = 0; break; }
                        by = ground;
                        if (ps == PetState.Crazy || ps == PetState.Dodge)
                        {
                            st = BState.Flee; stateTime = 0;
                            if (ps == PetState.Crazy) Say(Pick(FLEE), 2f);
                            break;
                        }
                        if ((ps == PetState.Shoot || ps == PetState.Bazooka) && lastPetState != ps && Math.Abs(bx - pet.PetX) < 300 * S && rnd.NextDouble() < 0.25)
                            Say(Pick(EARS), 1.8f);

                        float tx = pet.PetOnGround ? pet.PetX - pet.PetFacing * 110 * S : pet.PetX;
                        float dx = tx - bx;
                        if (Math.Abs(dx) > 25 * S)
                        {
                            float speed = Math.Abs(dx) > 500 * S ? 250f : 100f;
                            int dir = dx < 0 ? -1 : 1;
                            float g2 = Floors.At(bx + dir * 25 * S, by, 20 * S).Bounds.Bottom - 2 * S;
                            if (by - g2 > 12 * S)
                            {
                                vx = dir * 220f * S; vy = -(float)Math.Sqrt(2 * 1900f * S * (by - g2 + 45 * S));
                                st = BState.Fall; stateTime = 0; facing = dir;
                                break;
                            }
                            bx += dir * Math.Min(Math.Abs(dx), speed * S * dt);
                            facing = dir; walking = true; walkPhase += dt * (speed > 200 ? 18f : 12f);
                        }
                        else facing = pet.PetX < bx ? -1 : 1;

                        if (!pet.PetOnGround && ps != PetState.Fall && ps != PetState.Drag)
                        {
                            waitTalk -= dt;
                            if (waitTalk <= 0) { waitTalk = 25f + (float)rnd.NextDouble() * 20f; if (!pet.PetCalm) Say(Pick(WAIT), 2.5f); }
                        }
                        if (ps == PetState.Sleep && !walking)
                        {
                            sleepWait += dt;
                            if (sleepWait > 2.5f) { st = BState.Sleep; stateTime = 0; sleepWait = 0; speech = null; }
                        }
                        else sleepWait = 0;
                    }
                    break;
            }
            lastPetState = ps;

            // alarma: Pipo da saltitos para llamar la atencion
            if (alarmLeft > 0 && st == BState.Follow)
            {
                hopTimer -= dt;
                if (hopTimer <= 0) { hopTimer = 0.55f; vy = -520f * S; vx = 0; st = BState.Fall; stateTime = 0; }
            }

            bool calm = !walking && st != BState.Fall && st != BState.Drag && squash <= 0 && alarmLeft <= 0;
            int every = timerLeft > 0 ? 8 : (Native.IdleMs() > 180000 ? 15 : 6);
            if (!calm || tick % every == 0 || speech != lastDrawn) Render(S);
        }

        void Render(float S)
        {
            int W = (int)(LW * S), H = (int)(LH * S);
            int left = (int)Math.Round(bx - FX * S), top = (int)Math.Round(by - FY * S);
            using (Graphics g = surf.Begin(W, H))
            {
                g.ScaleTransform(S, S);
                GraphicsState gs = g.Save();
                g.TranslateTransform(FX, FY);
                if (facing < 0) g.ScaleTransform(-1, 1);
                if (walking) g.RotateTransform(st == BState.Flee ? 10f : 4f);
                if (squash > 0) g.ScaleTransform(1f + 0.3f * squash, 1f - 0.3f * squash);
                DrawPipo(g);
                g.Restore(gs);
                if (st == BState.Sleep) DrawZzz(g);
                if (timerLeft > 0) DrawTimer(g);
                if (speech != null) DrawBubble(g, speech);
            }
            lastDrawn = speech;
            surf.Present(Handle, left, top, W, H);
        }

        static Color C(string hex) { return ColorTranslator.FromHtml(hex); }

        void DrawPipo(Graphics g)
        {
            Color ink = C("#111111");
            bool air = st == BState.Fall || st == BState.Drag;
            bool scared = st == BState.Flee || air;
            float bob = walking ? -Math.Abs((float)Math.Sin(walkPhase)) * 2.5f : (float)Math.Sin(t * 2.6f) * 0.8f;
            if (st == BState.Sleep) bob = (float)Math.Sin(t * 1.5f) * 0.8f;

            // sombra en el suelo
            if (st != BState.Drag)
            {
                float hgt = st == BState.Fall ? Math.Max(0, (Floors.At(bx, by, 20 * pet.PetScale).Bounds.Bottom - 2 * pet.PetScale - by) / pet.PetScale) : 0;
                if (hgt < 150)
                {
                    float k = 1f - hgt / 150f;
                    using (GraphicsPath sp = new GraphicsPath())
                    {
                        sp.AddEllipse(-16 * (0.5f + 0.5f * k), hgt - 4, 32 * (0.5f + 0.5f * k), 7);
                        using (PathGradientBrush sb = new PathGradientBrush(sp))
                        {
                            sb.CenterColor = Color.FromArgb((int)(100 * k), 0, 0, 0);
                            sb.SurroundColors = new Color[] { Color.FromArgb(0, 0, 0, 0) };
                            g.FillPath(sb, sp);
                        }
                    }
                }
            }

            // piernas
            float sw = walking ? (float)Math.Sin(walkPhase) * 5f : (air ? (float)Math.Sin(t * 14f) * 4f : 0f);
            using (Pen leg = new Pen(ink, 3f))
            {
                leg.StartCap = LineCap.Round; leg.EndCap = LineCap.Round;
                g.DrawLine(leg, -5, -14 + bob, -5 + sw, -2);
                g.DrawLine(leg, 5, -14 + bob, 5 - sw, -2);
            }
            using (SolidBrush shoe = new SolidBrush(C("#7A4A1E")))
            {
                g.FillEllipse(shoe, -9 + sw, -5, 10, 6);
                g.FillEllipse(shoe, 1 - sw, -5, 10, 6);
            }

            // brazos
            using (Pen arm = new Pen(ink, 2.5f))
            {
                arm.StartCap = LineCap.Round; arm.EndCap = LineCap.Round;
                if (scared)
                {
                    float wv = (float)Math.Sin(t * 20f) * 3f;
                    g.DrawLine(arm, -12, -34 + bob, -20, -50 + bob + wv);
                    g.DrawLine(arm, 12, -34 + bob, 20, -50 + bob - wv);
                }
                else
                {
                    float as2 = walking ? (float)Math.Sin(walkPhase) * 4f : 0f;
                    g.DrawLine(arm, -12, -33 + bob, -18 - as2, -22 + bob);
                    g.DrawLine(arm, 12, -33 + bob, 18 + as2, -22 + bob);
                }
            }

            // cuerpo de pipa
            using (GraphicsPath body = new GraphicsPath())
            {
                body.AddBezier(0, -68 + bob, 15, -60 + bob, 18, -28 + bob, 0, -12 + bob);
                body.AddBezier(0, -12 + bob, -18, -28 + bob, -15, -60 + bob, 0, -68 + bob);
                body.CloseFigure();
                using (SolidBrush dark = new SolidBrush(C("#2A2A2E"))) g.FillPath(dark, body);
                GraphicsState cs = g.Save();
                g.SetClip(body);
                using (Pen stripe = new Pen(Color.FromArgb(225, 236, 236, 236), 2.6f))
                {
                    g.DrawBezier(stripe, -2, -68 + bob, -9, -55 + bob, -12, -30 + bob, -6, -12 + bob);
                    g.DrawBezier(stripe, 2, -68 + bob, 9, -55 + bob, 12, -30 + bob, 6, -12 + bob);
                    g.DrawLine(stripe, 0, -68 + bob, 0, -12 + bob);
                }
                using (PathGradientBrush shade = new PathGradientBrush(body))
                {
                    shade.CenterPoint = new PointF(-3, -48 + bob);
                    shade.CenterColor = Color.FromArgb(0, 0, 0, 0);
                    shade.SurroundColors = new Color[] { Color.FromArgb(150, 0, 0, 0) };
                    shade.FocusScales = new PointF(0.55f, 0.6f);
                    g.FillPath(shade, body);
                }
                using (GraphicsPath hp = new GraphicsPath())
                {
                    hp.AddEllipse(-11, -60 + bob, 9, 20);
                    using (PathGradientBrush hl = new PathGradientBrush(hp))
                    {
                        hl.CenterColor = Color.FromArgb(130, 255, 255, 255);
                        hl.SurroundColors = new Color[] { Color.FromArgb(0, 255, 255, 255) };
                        g.FillPath(hl, hp);
                    }
                }
                g.Restore(cs);
                using (Pen o = new Pen(ink, 2.4f)) g.DrawPath(o, body);
            }

            // casco
            using (LinearGradientBrush helm = new LinearGradientBrush(new RectangleF(-13, -79 + bob, 26, 12), C("#86A95E"), C("#3E5A26"), 70f))
            using (SolidBrush helmDark = new SolidBrush(C("#33491F")))
            using (Pen o = new Pen(ink, 1.8f))
            {
                g.FillPie(helm, -13, -78 + bob, 26, 22, 180, 180);
                g.DrawArc(o, -13, -78 + bob, 26, 22, 180, 180);
                g.FillRectangle(helmDark, -15, -68 + bob, 30, 3.5f);
                g.DrawRectangle(o, -15, -68 + bob, 30, 3.5f);
            }

            // cara
            using (SolidBrush white = new SolidBrush(Color.White))
            using (SolidBrush pupil = new SolidBrush(ink))
            using (Pen p = new Pen(ink, 1.6f))
            {
                p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
                float[] ex = { -2, 7 };
                float ey = -46 + bob;
                bool closed = st == BState.Sleep || blinkLeft > 0;
                for (int i = 0; i < 2; i++)
                {
                    if (closed) { g.DrawArc(p, ex[i] - 4, ey - 1, 8, 5, 10, 160); continue; }
                    float ew = scared ? 10 : 8, eh = scared ? 11 : 9;
                    g.FillEllipse(white, ex[i] - ew / 2, ey - eh / 2, ew, eh);
                    float ps2 = scared ? 2.5f : 4f;
                    float lk = scared ? 0 : 1.2f;
                    g.FillEllipse(pupil, ex[i] - ps2 / 2 + lk, ey - ps2 / 2 + 0.5f, ps2, ps2 + 0.5f);
                }
                if (scared)
                {
                    using (SolidBrush m = new SolidBrush(C("#7A1A1A"))) g.FillEllipse(m, 1, -38 + bob, 5, 6);
                    using (SolidBrush sweat = new SolidBrush(Color.FromArgb(210, 120, 190, 255))) g.FillEllipse(sweat, -13, -56 + bob + (t * 25f % 8f), 4, 6);
                }
                else if (st == BState.Sleep) g.DrawEllipse(p, 2, -37 + bob, 3, 3);
                else g.DrawArc(p, -1, -41 + bob, 9, 6, 20, 140);
            }
            using (SolidBrush blush = new SolidBrush(Color.FromArgb(90, 240, 110, 110))) g.FillEllipse(blush, 9, -40 + bob, 5, 3);
        }

        void DrawTimer(Graphics g)
        {
            int secs = (int)Math.Ceiling(timerLeft);
            string txt = (secs >= 3600 ? (secs / 3600) + ":" + ((secs / 60) % 60).ToString("00") : (secs / 60).ToString()) + ":" + (secs % 60).ToString("00");
            if (pomodoro) txt = (pomoWork ? "Trabajo " : "Descanso ") + txt;
            Font f = PIPO_TIMER_FONT;
            {
                SizeF sz = g.MeasureString(txt, f);
                float w = sz.Width + 14, h = 20;
                float x = FX + 22, y = FY - 74;
                Color col = pomodoro && !pomoWork ? Color.FromArgb(235, 46, 125, 50) : (timerLeft < 60 ? Color.FromArgb(235, 198, 40, 40) : Color.FromArgb(235, 40, 40, 48));
                using (GraphicsPath p = new GraphicsPath())
                {
                    p.AddArc(x, y, h, h, 90, 180);
                    p.AddArc(x + w - h, y, h, h, 270, 180);
                    p.CloseFigure();
                    using (SolidBrush b = new SolidBrush(col)) g.FillPath(b, p);
                    float prog = timerTotal > 0 ? Math.Max(0, Math.Min(1, 1f - timerLeft / timerTotal)) : 0;
                    using (SolidBrush pb = new SolidBrush(Color.FromArgb(90, 255, 255, 255)))
                    {
                        GraphicsState gs = g.Save();
                        g.SetClip(p);
                        g.FillRectangle(pb, x, y + h - 3, w * prog, 3);
                        g.Restore(gs);
                    }
                }
                using (SolidBrush tb = new SolidBrush(Color.White)) g.DrawString(txt, f, tb, x + 7, y + 2);
            }
        }

        void DrawZzz(Graphics g)
        {
            for (int i = 0; i < 3; i++)
            {
                float ph = (t * 0.6f + i * 0.33f) % 1f;
                using (Font f = new Font("Segoe UI", 9f + ph * 7f, FontStyle.Bold, GraphicsUnit.Pixel))
                using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(220 * (1 - ph)), 60, 60, 90)))
                    g.DrawString("z", f, b, FX + 10 + ph * 20, FY - 80 - ph * 35);
            }
        }

        void DrawBubble(Graphics g, string text)
        {
            Font f = PIPO_FONT;
            {
                SizeF sz = g.MeasureString(text, f, 220);
                float w = sz.Width + 18, h = sz.Height + 10;
                float x = Math.Max(4, Math.Min(LW - w - 4, FX - w / 2));
                float y = Math.Max(4, FY - 90 - h);
                using (GraphicsPath p = new GraphicsPath())
                {
                    float r = 8;
                    p.AddArc(x, y, r * 2, r * 2, 180, 90);
                    p.AddArc(x + w - r * 2, y, r * 2, r * 2, 270, 90);
                    p.AddArc(x + w - r * 2, y + h - r * 2, r * 2, r * 2, 0, 90);
                    p.AddArc(x, y + h - r * 2, r * 2, r * 2, 90, 90);
                    p.CloseFigure();
                    PointF[] tail = { new PointF(FX - 6, y + h - 1), new PointF(FX + 6, y + h - 1), new PointF(FX, y + h + 10) };
                    using (SolidBrush wb = new SolidBrush(Color.FromArgb(255, 252, 240)))
                    using (Pen o = new Pen(Color.FromArgb(40, 30, 20), 2f))
                    {
                        g.FillPolygon(wb, tail);
                        g.DrawLine(o, tail[0], tail[2]); g.DrawLine(o, tail[1], tail[2]);
                        g.DrawPath(o, p); g.FillPath(wb, p); g.DrawPath(o, p);
                        using (Pen cover = new Pen(Color.FromArgb(255, 252, 240), 2.4f)) g.DrawLine(cover, tail[0].X + 1.5f, tail[0].Y, tail[1].X - 1.5f, tail[1].Y);
                    }
                }
                using (SolidBrush tb = new SolidBrush(C("#1E1E1E")))
                    g.DrawString(text, f, tb, new RectangleF(x + 9, y + 5, sz.Width + 2, sz.Height + 2));
            }
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left) { mouseDown = true; dragging = false; downX = Cursor.Position.X; downY = Cursor.Position.Y; }
            base.OnMouseDown(e);
        }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (mouseDown && !dragging)
            {
                Point c = Cursor.Position;
                if (Math.Abs(c.X - downX) + Math.Abs(c.Y - downY) > 6)
                {
                    dragging = true; st = BState.Drag; stateTime = 0; vx = 0; vy = 0;
                    offX = downX - bx; offY = downY - by;
                    Say("¡Socorro! ¡Me abducen!", 2f);
                }
            }
            base.OnMouseMove(e);
        }
        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                bool wasDrag = dragging;
                mouseDown = false; dragging = false;
                if (wasDrag) { st = BState.Fall; stateTime = 0; }
                else
                {
                    if (st == BState.Sleep) st = BState.Follow;
                    if (alarmLeft > 0) { alarmLeft = 0; Say("Vale, vale, ya paro.", 1.5f); }
                    else pmenu.Show(Cursor.Position);
                }
            }
            else if (e.Button == MouseButtons.Right) pmenu.Show(Cursor.Position);
            base.OnMouseUp(e);
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            pet.PomodoroFocus = false;
            surf.Dispose();
            base.OnFormClosed(e);
        }
    }

    // ============================ ventana de ajustes ============================
    public class SettingsForm : Form
    {
        PetForm pet;
        TextBox diaryBox;

        public SettingsForm(PetForm p)
        {
            pet = p;
            Text = "Cacahuete Comando · Ajustes";
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Segoe UI", 9.5f);
            ClientSize = new Size(480, 440);
            TopMost = true;
            ShowInTaskbar = false;

            TabControl tabs = new TabControl();
            tabs.Dock = DockStyle.Fill;
            Controls.Add(tabs);

            // ---- General ----
            TabPage gen = Page(tabs, "General");
            int y = 18;
            Lbl(gen, "Tamaño", y);
            ComboBox size = new ComboBox();
            size.DropDownStyle = ComboBoxStyle.DropDownList;
            size.SetBounds(230, y - 3, 200, 26);
            string[] names = { "Pequeño", "Normal", "Grande", "Enorme" };
            float[] vals = { 0.7f, 1f, 1.4f, 1.8f };
            size.Items.AddRange(names);
            int sel = 1;
            for (int i = 0; i < vals.Length; i++) if (Math.Abs(vals[i] - pet.SizeMul) < 0.01f) sel = i;
            size.SelectedIndex = sel;
            size.SelectedIndexChanged += delegate { pet.SetSize(vals[size.SelectedIndex]); };
            gen.Controls.Add(size);
            y += 44;
            Chk(gen, "Sonido", y, "Sound", true); y += 34;
            CheckBox auto = new CheckBox();
            auto.Text = "Arrancar con Windows"; auto.AutoSize = true; auto.Location = new Point(20, y);
            auto.Checked = AutoStart.IsOn();
            auto.CheckedChanged += delegate { AutoStart.Set(auto.Checked); };
            gen.Controls.Add(auto);
            y += 34;
            Chk(gen, "Pipo, el recluta pipa (compañero)", y, "Buddy", true); y += 34;
            Chk(gen, "Gráficos realistas (imágenes de la carpeta sprites)", y, "Sprites", false); y += 44;
            Note(gen, "El Cacahuete se actualiza solo cuando cambia cacahuete.ps1.", y);

            // ---- Comportamiento ----
            TabPage beh = Page(tabs, "Comportamiento");
            y = 14;
            Slider(beh, "Ganas de disparar", y, "ShootMul"); y += 62;
            Slider(beh, "Ataques de locura", y, "CrazyMul"); y += 66;
            Chk(beh, "Trepar a ventanas y al techo", y, "Climb", true); y += 32;
            Chk(beh, "Viajar entre pantallas", y, "Travel", true); y += 32;
            Chk(beh, "Reaccionar a tus apps (Steam, YouTube, Spotify...)", y, "ReactApps", true); y += 32;
            Chk(beh, "Modo concentración al programar (no dispara)", y, "Focus", true); y += 32;

            // ---- Recordatorios ----
            TabPage rem = Page(tabs, "Recordatorios");
            y = 20;
            Num(rem, "Levántate cada (minutos, 0 = nunca)", y, "SitMin", 60); y += 44;
            Num(rem, "Bebe agua cada (minutos, 0 = nunca)", y, "WaterMin", 45); y += 50;
            Chk(rem, "De madrugada, mandarme a dormir", y, "Night", true); y += 44;
            Note(rem, "Solo cuenta el tiempo que estás usando el ordenador.", y);

            // ---- Diario ----
            TabPage dia = Page(tabs, "Diario de guerra");
            diaryBox = new TextBox();
            diaryBox.Multiline = true; diaryBox.ReadOnly = true; diaryBox.ScrollBars = ScrollBars.Vertical;
            diaryBox.Font = new Font("Segoe UI", 10f);
            diaryBox.SetBounds(12, 12, 440, 330);
            diaryBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
            dia.Controls.Add(diaryBox);
            Button refresh = new Button();
            refresh.Text = "Actualizar"; refresh.SetBounds(12, 350, 120, 30);
            refresh.Click += delegate { FillDiary(); };
            dia.Controls.Add(refresh);
            FillDiary();
        }

        void FillDiary() { diaryBox.Text = pet.diary.History(7).Replace("\n", "\r\n").Replace("\r\r\n", "\r\n"); }

        protected override CreateParams CreateParams
        {
            get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x00000080; return cp; } // que el mosaico no la coja
        }

        static TabPage Page(TabControl tabs, string title)
        {
            TabPage tp = new TabPage(title);
            tp.Padding = new Padding(8);
            tp.UseVisualStyleBackColor = true;
            tabs.TabPages.Add(tp);
            return tp;
        }

        static void Lbl(Control parent, string text, int y)
        {
            Label l = new Label(); l.Text = text; l.AutoSize = true; l.Location = new Point(20, y);
            parent.Controls.Add(l);
        }

        static void Note(Control parent, string text, int y)
        {
            Label l = new Label(); l.Text = text; l.AutoSize = true; l.Location = new Point(20, y);
            l.ForeColor = Color.Gray;
            parent.Controls.Add(l);
        }

        void Chk(Control parent, string text, int y, string key, bool def)
        {
            CheckBox c = new CheckBox();
            c.Text = text; c.AutoSize = true; c.Location = new Point(20, y);
            c.Checked = Settings.Get(key, def ? "1" : "0") != "0";
            c.CheckedChanged += delegate { Settings.Set(key, c.Checked ? "1" : "0"); pet.ReloadCfg(); };
            parent.Controls.Add(c);
        }

        void Slider(Control parent, string text, int y, string key)
        {
            string[] labels = { "Nada", "Pocas", "Normal", "Bastantes", "Muchísimas" };
            Lbl(parent, text, y);
            Label val = new Label(); val.AutoSize = true; val.Location = new Point(360, y);
            parent.Controls.Add(val);
            TrackBar tb = new TrackBar();
            tb.Minimum = 0; tb.Maximum = 4; tb.TickStyle = TickStyle.BottomRight;
            tb.SetBounds(16, y + 20, 420, 36);
            int v = (int)Math.Round(Settings.GetF(key, 1f) * 2f);
            tb.Value = Math.Max(0, Math.Min(4, v));
            val.Text = labels[tb.Value];
            tb.ValueChanged += delegate { val.Text = labels[tb.Value]; Settings.SetF(key, tb.Value / 2f); pet.ReloadCfg(); };
            parent.Controls.Add(tb);
        }

        void Num(Control parent, string text, int y, string key, int def)
        {
            Lbl(parent, text, y + 3);
            NumericUpDown n = new NumericUpDown();
            n.Minimum = 0; n.Maximum = 480; n.Increment = 5;
            n.SetBounds(350, y, 80, 26);
            n.Value = Math.Max(0, Math.Min(480, (int)Settings.GetF(key, def)));
            n.ValueChanged += delegate { Settings.SetF(key, (float)n.Value); pet.ReloadCfg(); };
            parent.Controls.Add(n);
        }
    }

    // ============================ EL CACAHUETE ============================
    public class PetForm : Form
    {
        const int LW = 760, LH = 560;
        const float AX = 380f, AY = 290f;   // centro del cacahuete dentro de su ventana (logico)

        const int K_CASING = 0, K_CONFETTI = 1, K_SMOKE = 2, K_FRAG = 3, K_MAG = 4, K_DROP = 5;

        float dpiScale = 1f, sizeMul = 1f, S = 1f;
        int W, H;
        Surface frame = new Surface();

        // ajustes
        public float shootMul = 1f, crazyMul = 1f;
        public bool travelOn = true, climbOn = true, nightOn = true, reactApps = true, focusOn = true, buddyOn = true;
        public int sitMin = 60, waterMin = 45;
        public bool spritesOn = false;
        SpriteSet sprites;

        // trinchera
        IntPtr trenchHwnd; Native.RECT trenchRect; int trenchSide; bool trenchPeek, trenchInside;
        float trenchSwitch, trenchShot;

        // apps
        bool focusMode; string lastProc = "", lastTitle = "";
        Dictionary<string, float> reacted = new Dictionary<string, float>();

        // diario de guerra
        public Diary diary = new Diary();
        float diarySave, updateCheck;

        // companero
        BuddyForm buddy;
        float dialogTimer = 90f; string pendingReply; float replyIn;
        SettingsForm settingsWin;
        string lastDrawnSpeech;
        float squash, lean;
        Random rnd = new Random();

        // posicion de los pies en pantalla (pixeles fisicos)
        float px, py, vx, vy;
        int facing = 1, moveDir = 1;
        PetState state = PetState.Idle;
        Orient orient = Orient.Floor;
        Surf surf = Surf.Ground;
        Weapon weapon = Weapon.AK;

        IntPtr platHwnd; Native.RECT platRect; float platTime, platDur;
        Goal goal = Goal.None; float goalX; IntPtr goalHwnd; int climbSide; float climbTargetY;

        float stateTime, stateDur, t, walkPhase, blinkTimer = 2f, blinkLeft;
        float recoil, flashLeft, shotTimer, afterBurst;
        int shotsLeft, ammo = 30, hopsLeft;
        float dragOffX, dragOffY;
        bool mouseDownLeft, dragging;
        int downX, downY;
        bool angry;
        float anger, lastInteraction;
        string speech; float speechLeft;
        bool soundOn = true;
        DateTime quietUntil = DateTime.MinValue;
        bool hiddenFS;
        int tick, renders;
        float crazyAngle, crazySoundTimer, crazyTalkTimer;
        bool chute, chuteArmed;
        bool hasAim; PointF aimTarget; bool fireAfterGuard;
        int squatReps; float squatPhase;
        float dodgeTime, dodgeCountdown, dodgeShot, bestDodge; bool dodgeRunning;
        float musicOn, musicOff, musicLevel, musicCooldown, lastSoundTime = -10f, audioReinit;
        float sitTime, waterTime, nightNag = 600f;
        float reactCooldown = 10f; IntPtr lastFg; Native.RECT lastFgRect;
        float envAcc, musicAcc, lastTime;
        bool overlayDirty;

        List<Bullet> bullets = new List<Bullet>();
        List<Hole> holes = new List<Hole>();
        List<Part> parts = new List<Part>();
        List<Ring> rings = new List<Ring>();
        List<Popup> popups = new List<Popup>();
        List<Splat> splats = new List<Splat>();
        List<Blob> blobs = new List<Blob>();
        List<Grenade> grenades = new List<Grenade>();

        OverlayForm overlay;
        AudioMeter meter = new AudioMeter();
        SoundPlayer player;
        System.Windows.Forms.Timer timer;
        System.Diagnostics.Stopwatch clock = new System.Diagnostics.Stopwatch();
        ContextMenuStrip menu;
        ToolStripMenuItem soundItem, sleepItem, autoItem, quietItem, dodgeItem, sizeMenu;

        static readonly string[] SHOOT_LINES = {
            "¡RATATATÁ!", "¡PEW PEW PEW!", "¡A CUBIERTO!", "¡CACAHUETE AL ATAQUE!",
            "¡SOY ALÉRGICO A LA PAZ!", "¡NO SOY UN FRUTO SECO CUALQUIERA!", "¡FUEGO A DISCRECIÓN!" };
        static readonly string[] IDLE_LINES = {
            "¿Alguien ha dicho mantequilla?", "Técnicamente soy una legumbre.", "No me confundas con una almendra.",
            "Vigilando el escritorio...", "Esas pestañas no se cierran solas.", "Huele a pipas... competencia.",
            "Despejado. De momento.", "Ni un paso atrás. Ni uno.", "Tengo cáscara, no miedo." };
        static readonly string[] POKE_LINES = { "¡EH! ¡Sin tocar!", "¿Me buscas?", "¡Te he visto!", "¡Tú lo has querido!", "Como me sigas pinchando..." };
        static readonly string[] FALL_LINES = { "¡AY!", "¡Mis cáscaras!", "Eso ha dolido...", "¡Pienso denunciar!" };
        static readonly string[] DRAG_LINES = { "¡Bájame!", "¡Que me mareo!", "¡Suéltame, civil!" };
        static readonly string[] DANCE_LINES = { "¡Baile de la victoria!", "Esto es el cacahuete-step.", "¡Ritmo militar!" };
        static readonly string[] WAKE_LINES = { "¡¿QUIÉN ANDA AHÍ?!", "¡Estaba despierto!", "¡Emboscada!" };
        static readonly string[] CRAZY_LINES = {
            "¡¡AAAAAAAAHHHHH!!", "¡NADIE SALE VIVO DE ESTE ESCRITORIO!", "¡¡LAS PIPAS ME LAS PAGÁIS TODAS!!",
            "¡¡MODO MANTEQUILLA ACTIVADO!!", "¡¡SOY UN FRUTO SECO... Y ESTOY LOCO!!", "¡¡A POR LA PAPELERA DE RECICLAJE!!",
            "¡¡QUE ARDA EL EXPLORADOR DE ARCHIVOS!!" };
        static readonly string[] RELOAD_LINES = { "¡RECARGANDO! ¡CUBRIDME!", "¡CUBRIDME!", "¡Cargador vacío! ¡Un segundo!" };
        static readonly string[] MOVE_LINES = { "¡Esa ventana se mueve! ¡Alto ahí!", "¡Movimiento sospechoso!", "¡Quieta, ventana!" };
        static readonly string[] TRENCH_LINES = { "¡Fuego de cobertura!", "¡Desde la trinchera!", "Asomo un ojo...", "¡Cubridme, que salgo!", "Esta ventana aguanta lo que le echen." };
        static readonly string[] BORED_LINES = { "¿Hola? ¿Hay alguien?", "Qué aburrimiento de guerra.", "Podrías hacerme caso, ¿eh?" };

        public PetForm()
        {
            using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) { dpiScale = g.DpiX / 96f; }
            if (dpiScale < 1f) dpiScale = 1f;
            Log.W("paso 4: constructor");
            sizeMul = Settings.GetF("Size", 1f);
            soundOn = Settings.Get("Sound", "1") != "0";
            bestDodge = Settings.GetF("BestDodge", 0f);
            ReloadCfg();
            diary.Load();
            ApplySize();

            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;
            Text = "Cacahuete Comando";
            Size = new Size(W, H);

            Rectangle b = Screen.PrimaryScreen.Bounds;
            px = b.Left + b.Width * 0.7f;
            py = Ground();
            NextIdle(2f);
            Greet();

            BuildMenu();
            Log.W("paso 5: menu OK");
            overlay = new OverlayForm();
            Log.W("paso 6: capa de efectos OK");
            audioReinit = 3f; // el medidor de audio se inicia unos segundos despues

            SystemEvents.DisplaySettingsChanged += OnDisplayChanged;

            timer = new System.Windows.Forms.Timer();
            timer.Interval = 33;   // ~30 fps, de sobra para una mascota
            timer.Tick += OnTick;
            clock.Start();
            timer.Start();
            Log.W("form creado. dpi=" + dpiScale + " tamano=" + sizeMul + " pantallas=" + Screen.AllScreens.Length + " escritorio=" + SystemInformation.VirtualScreen);
        }

        void ApplySize()
        {
            S = dpiScale * sizeMul;
            W = (int)(LW * S); H = (int)(LH * S);
            if (frame != null) { frame.Dispose(); frame = new Surface(); }
            if (bodyCache != null) { bodyCache.Dispose(); bodyCache = null; }
            if (bubbleCache != null) { bubbleCache.Dispose(); bubbleCache = null; bubbleKey = null; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x00080000; // WS_EX_LAYERED
                cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW (los gestores en mosaico la ignoran)
                cp.ExStyle |= 0x00000008; // WS_EX_TOPMOST
                cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
                return cp;
            }
        }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0021) { m.Result = (IntPtr)3; return; } // WM_MOUSEACTIVATE -> MA_NOACTIVATE
            base.WndProc(ref m);
        }
        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            overlay.Show();
            UpdateBuddy();
        }

        public void ReloadCfg()
        {
            shootMul = Settings.GetF("ShootMul", 1f);
            crazyMul = Settings.GetF("CrazyMul", 1f);
            travelOn = Settings.Get("Travel", "1") != "0";
            climbOn = Settings.Get("Climb", "1") != "0";
            nightOn = Settings.Get("Night", "1") != "0";
            reactApps = Settings.Get("ReactApps", "1") != "0";
            focusOn = Settings.Get("Focus", "1") != "0";
            buddyOn = Settings.Get("Buddy", "1") != "0";
            spritesOn = Settings.Get("Sprites", "0") != "0";
            if (spritesOn && sprites == null)
            {
                try { sprites = SpriteSet.Load(System.IO.Path.Combine(System.IO.Path.GetDirectoryName(AutoStart.ScriptPath), "sprites")); } catch { }
            }
            else if (!spritesOn && sprites != null) { sprites.Dispose(); sprites = null; }
            sitMin = (int)Settings.GetF("SitMin", 60);
            waterMin = (int)Settings.GetF("WaterMin", 45);
            soundOn = Settings.Get("Sound", "1") != "0";
            if (soundItem != null) soundItem.Checked = soundOn;
            if (IsHandleCreated) UpdateBuddy();
        }

        void UpdateBuddy()
        {
            if (buddyOn && buddy == null)
            {
                buddy = new BuddyForm(this);
                buddy.Show();
            }
            else if (!buddyOn && buddy != null)
            {
                buddy.Close(); buddy = null;
            }
        }

        public void SetSize(float mul)
        {
            sizeMul = mul; ApplySize(); Settings.SetF("Size", mul);
            SayAlways(mul > 1.5f ? "¡SOY ENORME!" : (mul < 0.9f ? "Me siento pequeñito." : "Tamaño reglamentario."), 2f);
        }
        public float SizeMul { get { return sizeMul; } }
        public float PetScale { get { return S; } }

        // datos que usa el companero
        public float PetX { get { return px; } }
        public float PetY { get { return py; } }
        public int PetFacing { get { return orient == Orient.Ceiling ? -facing : facing; } }
        public PetState PetStateNow { get { return state; } }
        public bool PetOnGround { get { return surf == Surf.Ground && orient == Orient.Floor; } }
        public bool PetHidden { get { return hiddenFS; } }
        public bool PetCalm { get { return Calm(); } }
        public bool PetSoundOn { get { return SoundOK(); } }
        public void ShowMenu() { lastInteraction = t; menu.Show(Cursor.Position); }

        public void OpenSettings()
        {
            if (settingsWin == null || settingsWin.IsDisposed) settingsWin = new SettingsForm(this);
            settingsWin.Show();
            settingsWin.Activate();
        }

        public void ShowDiary()
        {
            SayAlways(diary.Summary(), 7f);
        }

        // ================================ menu ================================
        void BuildMenu()
        {
            menu = new ContextMenuStrip();
            menu.Items.Add("¡Dispara!", null, delegate { if (state == PetState.Sleep) WakeUp(); StartBurstAt(true, Cursor.Position); });
            menu.Items.Add("¡MODO LOCO!", null, delegate { if (state == PetState.Sleep) WakeUp(); StartCrazy(); });

            ToolStripMenuItem arms = new ToolStripMenuItem("Armas");
            arms.DropDownItems.Add("Bazooka de mantequilla", null, delegate { if (state == PetState.Sleep) WakeUp(); StartBazooka(); });
            arms.DropDownItems.Add("Granada de pipa", null, delegate { if (state == PetState.Sleep) WakeUp(); StartThrow(); });
            arms.DropDownItems.Add("Lanzaconfeti", null, delegate { if (state == PetState.Sleep) WakeUp(); StartConfetti(); });
            menu.Items.Add(arms);

            ToolStripMenuItem climb = new ToolStripMenuItem("Trepar");
            climb.DropDownItems.Add("A la ventana activa", null, delegate { if (!TryClimbWindow(true)) SayAlways("No veo ninguna ventana a la que subirme.", 2.5f); });
            climb.DropDownItems.Add("Al techo", null, delegate { TryClimbCeiling(true); });
            climb.DropDownItems.Add("Bajar", null, delegate { if (surf != Surf.Ground && CanAct()) LeavePlatform(); });
            menu.Items.Add(climb);
            menu.Items.Add("Ir a otra pantalla", null, delegate { StartTravel(true); });
            menu.Items.Add("A la trinchera", null, delegate { if (!TryTrench(true)) SayAlways("No hay ninguna ventana buena para cubrirme.", 2.5f); });

            menu.Items.Add("Baila", null, delegate { StartDance(); });
            sleepItem = new ToolStripMenuItem("Duerme", null, delegate { if (state == PetState.Sleep) WakeUp(); else if (CanAct()) StartSleep(60f); });
            menu.Items.Add(sleepItem);
            dodgeItem = new ToolStripMenuItem("Minijuego: esquiva las balas", null, delegate { if (state == PetState.Dodge) StopDodge(); else StartDodge(); });
            menu.Items.Add(dodgeItem);
            menu.Items.Add(new ToolStripSeparator());

            sizeMenu = new ToolStripMenuItem("Tamaño");
            AddSize("Pequeño", 0.7f); AddSize("Normal", 1f); AddSize("Grande", 1.4f); AddSize("Enorme", 1.8f);
            menu.Items.Add(sizeMenu);

            soundItem = new ToolStripMenuItem("Sonido", null, delegate
            {
                soundOn = !soundOn; soundItem.Checked = soundOn; Settings.Set("Sound", soundOn ? "1" : "0");
            });
            soundItem.Checked = soundOn;
            menu.Items.Add(soundItem);

            quietItem = new ToolStripMenuItem("No molestar 1 hora", null, delegate
            {
                if (Quiet()) { quietUntil = DateTime.MinValue; SayAlways("¡De vuelta al servicio!", 2.5f); }
                else { quietUntil = DateTime.Now.AddHours(1); SayAlways("Entendido. Modo sigilo una hora.", 2.5f); }
            });
            menu.Items.Add(quietItem);

            autoItem = new ToolStripMenuItem("Arrancar con Windows", null, delegate
            {
                bool on = !AutoStart.IsOn();
                AutoStart.Set(on);
                autoItem.Checked = on;
                SayAlways(on ? "¡Me quedo de guardia para siempre!" : "Vale, mañana no vengo.", 2.5f);
            });
            autoItem.Checked = AutoStart.IsOn();
            menu.Items.Add(autoItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Diario de guerra", null, delegate { ShowDiary(); });
            menu.Items.Add("Ajustes...", null, delegate { OpenSettings(); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Retirada (salir)", null, delegate { Close(); });

            menu.Opened += delegate { MenuWatch.Watch(menu); };
            menu.Opening += delegate
            {
                sleepItem.Text = state == PetState.Sleep ? "Despierta" : "Duerme";
                dodgeItem.Text = state == PetState.Dodge ? "Parar minijuego" : "Minijuego: esquiva las balas";
                autoItem.Checked = AutoStart.IsOn();
                bool q = Quiet();
                quietItem.Checked = q;
                quietItem.Text = q ? "No molestar (hasta las " + quietUntil.ToString("HH:mm") + ")" : "No molestar 1 hora";
                foreach (ToolStripItem it in sizeMenu.DropDownItems)
                {
                    ToolStripMenuItem mi = it as ToolStripMenuItem;
                    if (mi != null) mi.Checked = Math.Abs((float)mi.Tag - sizeMul) < 0.01f;
                }
            };
        }

        void AddSize(string label, float mul)
        {
            ToolStripMenuItem it = new ToolStripMenuItem(label, null, delegate { SetSize(mul); });
            it.Tag = mul;
            sizeMenu.DropDownItems.Add(it);
        }

        // ============================== ayudas ==============================
        // ---- varias pantallas: el suelo es el borde inferior de la pantalla en la que esta ----
        Rectangle ceilScr; float ceilTop;
        Screen Scr() { return Floors.At(px, py, 20 * S); }
        float GroundOf(Screen s) { return s.Bounds.Bottom - 2 * S; }
        float CeilOf(Screen s) { return Math.Max(s.Bounds.Top, s.WorkingArea.Top); }
        float Ground() { return GroundOf(Scr()); }
        float CeilY() { return surf == Surf.Ceiling ? ceilTop : CeilOf(Scr()); }
        float MinX() { return SystemInformation.VirtualScreen.Left + 50 * S; }
        float MaxX() { return SystemInformation.VirtualScreen.Right - 50 * S; }
        float SurfY()
        {
            if (surf == Surf.WindowTop) return platRect.Top;
            if (surf == Surf.Ceiling) return CeilY();
            return Ground();
        }
        float SurfMin()
        {
            if (surf == Surf.WindowTop) return platRect.Left + 25 * S;
            if (surf == Surf.Ceiling) return ceilScr.Left + 60 * S;
            return MinX();
        }
        float SurfMax()
        {
            if (surf == Surf.WindowTop) return platRect.Right - 25 * S;
            if (surf == Surf.Ceiling) return ceilScr.Right - 60 * S;
            return MaxX();
        }

        string Pick(string[] a) { return a[rnd.Next(a.Length)]; }
        float Rand(float a, float b) { return a + (float)rnd.NextDouble() * (b - a); }
        bool Quiet() { return DateTime.Now < quietUntil; }
        public bool PomodoroFocus;
        bool Calm() { return Quiet() || focusMode || PomodoroFocus; }
        bool SoundOK() { return soundOn && !Quiet(); }
        void Say(string s, float secs) { if (Quiet()) return; speech = s; speechLeft = secs; }
        void SayAlways(string s, float secs) { speech = s; speechLeft = secs; }

        bool CanAct()
        {
            return state != PetState.Drag && state != PetState.Fall && state != PetState.Climb &&
                   state != PetState.Dodge && state != PetState.Crazy;
        }

        void FaceToward(float x)
        {
            if (orient == Orient.Floor) { moveDir = x < px ? -1 : 1; facing = moveDir; }
            else if (orient == Orient.Ceiling) { moveDir = x < px ? -1 : 1; facing = -moveDir; }
        }

        float OrientAngle()
        {
            switch (orient)
            {
                case Orient.Ceiling: return 180f;
                case Orient.WallLeft: return 90f;
                case Orient.WallRight: return -90f;
            }
            return 0f;
        }
        float CurrentAngle() { return OrientAngle() + (chute ? (float)Math.Sin(t * 1.4f) * 9f : 0f); }

        PointF PetToScreen(PointF local)
        {
            double r = CurrentAngle() * Math.PI / 180.0;
            float x = local.X * facing, y = local.Y;
            float sx = (float)(x * Math.Cos(r) - y * Math.Sin(r));
            float sy = (float)(x * Math.Sin(r) + y * Math.Cos(r));
            return new PointF(px + sx * S, py + sy * S);
        }

        void Greet()
        {
            int h = DateTime.Now.Hour;
            if (h >= 6 && h < 13) SayAlways("Buenos días, soldado. Cacahuete Comando, reportándose.", 4f);
            else if (h >= 13 && h < 21) SayAlways("Buenas tardes, recluta. Empieza la guardia.", 4f);
            else if (h >= 21 || h < 1) SayAlways("Buenas noches. Yo vigilo, tú descansa.", 4f);
            else SayAlways("¿Qué haces despierto a estas horas, soldado?", 4f);
        }

        // ============================== estados ==============================
        void NextIdle(float d) { state = PetState.Idle; stateTime = 0; stateDur = d; angry = false; hasAim = false; }

        void StartWalk(float d)
        {
            state = PetState.Walk; stateTime = 0; stateDur = d; goal = Goal.None;
            moveDir = rnd.Next(2) == 0 ? -1 : 1;
        }

        void ChooseNext()
        {
            bool quiet = Calm();
            double r = rnd.NextDouble();

            if (surf != Surf.Ground)
            {
                if (platTime > platDur) { LeavePlatform(); return; }
                if (r < 0.55) StartWalk(Rand(2f, 5f));
                else if (r < 0.65 && !quiet) StartBurstAt(false, PointF.Empty);
                else if (r < 0.72) LeavePlatform();
                else { NextIdle(Rand(2f, 4f)); if (rnd.NextDouble() < 0.3) Say(Pick(IDLE_LINES), 3f); }
                return;
            }

            bool bored = t - lastInteraction > 180f;
            if (bored && !quiet && rnd.NextDouble() < 0.3)
            {
                if (rnd.NextDouble() < 0.6) StartSquats(); else { NextIdle(3f); Say(Pick(BORED_LINES), 3f); }
                return;
            }

            if (quiet)
            {
                if (r < 0.6) StartWalk(Rand(2f, 6f));
                else if (r < 0.7) StartSleep(Rand(20f, 45f));
                else NextIdle(Rand(2f, 5f));
                return;
            }

            float extra = anger > 1f ? 0.12f : 0f;   // enfadado dispara mas
            bool multi = travelOn && Screen.AllScreens.Length > 1;
            double[] w = {
                0.34,                          // 0 andar
                (0.10 + extra) * shootMul,     // 1 rafaga
                0.05,                          // 2 bailar
                0.04,                          // 3 dormir
                0.025 * crazyMul,              // 4 loco
                0.035 * shootMul,              // 5 bazooka
                0.035 * shootMul,              // 6 granada
                0.035,                         // 7 confeti
                climbOn ? 0.05 : 0,            // 8 trepar ventana
                climbOn ? 0.04 : 0,            // 9 techo
                multi ? 0.06 : 0,              // 10 viajar
                0.06,                          // 11 trinchera
                0.20 };                        // 12 quieto
            double total = 0; foreach (double x in w) total += x;
            double pick = r * total, c = 0; int choice = w.Length - 1;
            for (int i = 0; i < w.Length; i++) { c += w[i]; if (pick < c) { choice = i; break; } }
            if (choice == 0) StartWalk(Rand(2f, 6f));
            else if (choice == 1) StartBurstAt(false, PointF.Empty);
            else if (choice == 2) StartDance();
            else if (choice == 3) StartSleep(Rand(20f, 45f));
            else if (choice == 4) StartCrazy();
            else if (choice == 5) StartBazooka();
            else if (choice == 6) StartThrow();
            else if (choice == 7) StartConfetti();
            else if (choice == 8) { if (!TryClimbWindow(false)) TryClimbCeiling(false); }
            else if (choice == 9) TryClimbCeiling(false);
            else if (choice == 10) StartTravel(false);
            else if (choice == 11 && TryTrench(false)) { }
            else
            {
                NextIdle(Rand(2f, 5f));
                if (rnd.NextDouble() < 0.45) Say(Pick(IDLE_LINES), 3.5f);
            }
        }

        void StartBurstAt(bool aim, PointF target)
        {
            if (!CanAct()) return;
            weapon = Weapon.AK;
            hasAim = aim && orient != Orient.WallLeft && orient != Orient.WallRight;
            aimTarget = target;
            if (hasAim) FaceToward(target.X);
            if (ammo <= 0) { StartReload(); return; }
            state = PetState.Shoot; stateTime = 0;
            shotsLeft = Math.Min(ammo, rnd.Next(6, 11)); shotTimer = 0; afterBurst = 0.6f;
            angry = true;
            Say(Pick(SHOOT_LINES), 1.8f);
            if (SoundOK()) PlayBurst(shotsLeft, 0.09);
        }

        void StartReload()
        {
            state = PetState.Reload; stateTime = 0; stateDur = 1.4f; weapon = Weapon.AK;
            Say(Pick(RELOAD_LINES), 1.6f);
            PointF m = GunPoint(new PointF(20, 14));
            AddPart(K_MAG, m.X, m.Y, -facing * Rand(40f, 90f) * S, -Rand(80f, 160f) * S, 1.5f, 9 * S, Color.FromArgb(196, 98, 28));
        }

        void StartDance()
        {
            if (!CanAct()) return;
            if (surf != Surf.Ground) { Say("Aquí arriba no, que me caigo.", 2f); return; }
            state = PetState.Dance; stateTime = 0; hopsLeft = 4; vy = 0;
            Say(Pick(DANCE_LINES), 2.5f);
        }

        void StartSleep(float d) { state = PetState.Sleep; stateTime = 0; stateDur = d; angry = false; hasAim = false; speech = null; }
        void WakeUp() { NextIdle(0.3f); angry = true; SayAlways(Pick(WAKE_LINES), 2f); }

        void StartCrazy()
        {
            if (state == PetState.Drag || state == PetState.Fall || state == PetState.Crazy || state == PetState.Dodge) return;
            if (orient == Orient.Ceiling) py += 140 * S;
            orient = Orient.Floor; surf = Surf.Ground; platHwnd = IntPtr.Zero; goal = Goal.None;
            weapon = Weapon.AK; hasAim = false;
            state = PetState.Crazy; stateTime = 0; stateDur = Rand(5.5f, 7.5f);
            diary.Crazy++;
            vy = -500f * S; vx = 0; shotTimer = 0; crazySoundTimer = 0; crazyTalkTimer = 1.6f;
            crazyAngle = 0; angry = true;
            SayAlways(Pick(CRAZY_LINES), 1.6f);
        }

        void StartSquats()
        {
            if (!CanAct() || surf != Surf.Ground) return;
            state = PetState.Squats; stateTime = 0; stateDur = 7f; squatReps = 0; squatPhase = 0;
            Say("Me aburro... ¡SENTADILLAS!", 2.2f);
        }

        void StartBazooka()
        {
            if (!CanAct()) return;
            weapon = Weapon.Bazooka; state = PetState.Bazooka; stateTime = 0; shotsLeft = 1;
            hasAim = false;
            Say("¡BAZOOKA DE MANTEQUILLA!", 2f);
        }

        void StartThrow()
        {
            if (!CanAct()) return;
            weapon = Weapon.AK; state = PetState.Throw; stateTime = 0; shotsLeft = 1; hasAim = false;
            Say("¡PIPA VA!", 1.6f);
        }

        void StartConfetti()
        {
            if (!CanAct()) return;
            weapon = Weapon.Confetti; state = PetState.Confetti; stateTime = 0; stateDur = 2.6f; hasAim = false;
            Say("¡LANZACONFETI DE GUERRA!", 2f);
            if (SoundOK()) PlayPop();
        }

        void StartGuard(PointF target, string line, double fireChance)
        {
            if (!(state == PetState.Idle || state == PetState.Walk) || goal != Goal.None) return;
            if (orient != Orient.Floor && orient != Orient.Ceiling) return;
            weapon = Weapon.AK;
            state = PetState.Guard; stateTime = 0; stateDur = 1.4f;
            hasAim = true; aimTarget = target; FaceToward(target.X);
            fireAfterGuard = rnd.NextDouble() < fireChance;
            angry = true;
            Say(line, 2.2f);
        }

        void StartMusicDance()
        {
            state = PetState.MusicDance; stateTime = 0; stateDur = 25f; hasAim = false;
            Say("¡TEMAZO!", 2f);
        }

        void StartDodge()
        {
            if (!CanAct() && state != PetState.Sleep) return;
            if (surf != Surf.Ground || orient != Orient.Floor) { SayAlways("Bájame al suelo primero.", 2f); return; }
            weapon = Weapon.AK; ammo = 30;
            state = PetState.Dodge; stateTime = 0;
            dodgeCountdown = 3.99f; dodgeRunning = false; dodgeTime = 0; dodgeShot = 0.6f;
            hasAim = true; aimTarget = Cursor.Position;
            SayAlways("¡MINIJUEGO! Esquiva las balas con el ratón.", 2.5f);
        }

        void StopDodge()
        {
            if (state != PetState.Dodge) return;
            dodgeRunning = false; NextIdle(1f); SayAlways("Cobarde.", 2f);
        }

        void DodgeOver(float x, float y)
        {
            dodgeRunning = false;
            AddPopup(x, y, "¡TE DI!", Color.FromArgb(230, 50, 50));
            AddRing(x, y, 45 * S, 0.35f);
            float sc = dodgeTime;
            bool rec = sc > bestDodge;
            if (rec) { bestDodge = sc; Settings.SetF("BestDodge", sc); }
            NextIdle(2f);
            SayAlways("Has aguantado " + sc.ToString("0.0") + " s." + (rec ? " ¡NUEVO RÉCORD!" : " Récord: " + bestDodge.ToString("0.0") + " s"), 5f);
        }

        // ---------------------------- trepar ----------------------------
        bool ValidClimbWindow(IntPtr h, out Native.RECT r)
        {
            r = new Native.RECT();
            if (h == IntPtr.Zero || h == Handle || h == overlay.Handle) return false;
            if (!Native.IsWindowVisible(h) || Native.IsIconic(h)) return false;
            string cls = Native.ClassOf(h);
            if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd") return false;
            if (!Native.GetWindowRect(h, out r)) return false;
            Screen ws = Screen.FromHandle(h);
            Rectangle sb = ws.Bounds;
            if (r.Right - r.Left < 300 * S || r.Bottom - r.Top < 150 * S) return false;
            if (r.Top < CeilOf(ws) + 70 * S || r.Top > GroundOf(ws) - 220 * S) return false;
            if (r.Left <= sb.Left && r.Right >= sb.Right && r.Top <= sb.Top) return false;
            return true;
        }

        bool TryClimbWindow(bool fromUser)
        {
            if (!CanAct() && state != PetState.Sleep) return false;
            if (surf != Surf.Ground) { if (fromUser) SayAlways("Ya estoy arriba.", 2f); return true; }
            IntPtr fg = Native.GetForegroundWindow();
            Native.RECT r;
            if (!ValidClimbWindow(fg, out r)) return false;
            Rectangle sb = Screen.FromHandle(fg).Bounds;
            bool leftOk = r.Left - sb.Left > 70 * S;
            bool rightOk = sb.Right - r.Right > 70 * S;
            if (!leftOk && !rightOk) return false;
            int side;
            if (leftOk && rightOk) side = Math.Abs(px - r.Left) < Math.Abs(px - r.Right) ? -1 : 1;
            else side = leftOk ? -1 : 1;
            goal = Goal.ClimbWindow; goalHwnd = fg; climbSide = side;
            goalX = side < 0 ? r.Left - 35 * S : r.Right + 35 * S;
            goalX = Math.Max(MinX(), Math.Min(MaxX(), goalX));
            state = PetState.Walk; stateTime = 0; hasAim = false; weapon = Weapon.AK;
            if (fromUser) SayAlways("¡Voy para arriba!", 2f); else Say("Voy a subirme ahí.", 2f);
            return true;
        }

        void TryClimbCeiling(bool fromUser)
        {
            if (!CanAct() && state != PetState.Sleep) return;
            if (surf != Surf.Ground) { if (fromUser) SayAlways("Ya estoy arriba.", 2f); return; }
            Screen cs = Scr();
            Rectangle sb = cs.Bounds;
            ceilScr = sb; ceilTop = CeilOf(cs);
            climbSide = px < sb.Left + sb.Width / 2 ? -1 : 1;
            goal = Goal.ClimbCeiling;
            goalX = climbSide < 0 ? sb.Left + 50 * S : sb.Right - 50 * S;
            state = PetState.Walk; stateTime = 0; hasAim = false; weapon = Weapon.AK;
            if (fromUser) SayAlways("¡A patrullar el techo!", 2f); else Say("Voy a patrullar el techo.", 2f);
        }

        bool ValidTrench(IntPtr h, out Native.RECT r, out int side)
        {
            r = new Native.RECT(); side = 0;
            if (h == IntPtr.Zero || h == Handle || h == overlay.Handle || (buddy != null && h == buddy.Handle)) return false;
            if (!Native.IsWindowVisible(h) || Native.IsIconic(h)) return false;
            string cls = Native.ClassOf(h);
            if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd") return false;
            if (!Native.GetWindowRect(h, out r)) return false;
            Screen ws = Screen.FromHandle(h);
            Rectangle sb = ws.Bounds;
            float gnd = GroundOf(ws);
            if (r.Right - r.Left < 250 * S || r.Bottom < gnd - 90 * S || r.Top > gnd - 200 * S) return false;
            bool leftOk = r.Left - sb.Left > 45 * S;
            bool rightOk = sb.Right - r.Right > 45 * S;
            if (!leftOk && !rightOk) return false;
            if (leftOk && rightOk) side = Math.Abs(px - r.Left) < Math.Abs(px - r.Right) ? -1 : 1;
            else side = leftOk ? -1 : 1;
            return true;
        }

        float TrenchEdge() { return trenchSide < 0 ? trenchRect.Left : trenchRect.Right; }

        bool TryTrench(bool fromUser)
        {
            if (!CanAct() && state != PetState.Sleep) return false;
            if (surf != Surf.Ground) return false;
            IntPtr fg = Native.GetForegroundWindow();
            Native.RECT r; int side;
            if (!ValidTrench(fg, out r, out side)) return false;
            trenchHwnd = fg; trenchRect = r; trenchSide = side; trenchInside = false;
            goal = Goal.Trench;
            goalX = TrenchEdge() + side * 24 * S;
            goalX = Math.Max(MinX(), Math.Min(MaxX(), goalX));
            state = PetState.Walk; stateTime = 0; hasAim = false; weapon = Weapon.AK;
            if (fromUser) SayAlways("¡A la trinchera!", 2f); else Say("Me pongo a cubierto.", 2f);
            return true;
        }

        void BeginTrench()
        {
            state = PetState.Trench; stateTime = 0; stateDur = Rand(12f, 20f);
            trenchPeek = false; trenchSwitch = Rand(1.2f, 2.2f); shotsLeft = 0; trenchShot = 0;
            facing = trenchSide; moveDir = trenchSide; hasAim = false; weapon = Weapon.AK;
        }

        // si la pantalla de delante tiene el suelo mas alto, salta para subirse
        bool StepUpAhead()
        {
            if (surf != Surf.Ground || orient != Orient.Floor) return false;
            float ahead = px + moveDir * 30 * S;
            float g2 = Floors.At(ahead, py, 20 * S).Bounds.Bottom - 2 * S;
            float h = py - g2;
            if (h <= 12 * S) return false;
            Goal keep = goal; float keepX = goalX;
            float grav = 1900f * S;
            BeginFall(moveDir * 230f * S, -(float)Math.Sqrt(2 * grav * (h + 55 * S)));
            goal = keep; goalX = keepX;
            chuteArmed = false;
            Say(h > 150 * S ? "¡SALTO DE COMANDO!" : "¡Hop!", 1.5f);
            return true;
        }

        bool StartTravel(bool fromUser)
        {
            Screen[] all = Screen.AllScreens;
            if (all.Length < 2) { if (fromUser) SayAlways("Solo veo una pantalla, soldado.", 2.5f); return false; }
            if (!CanAct() && state != PetState.Sleep) return false;
            if (surf != Surf.Ground) { if (fromUser) SayAlways("Bájame primero.", 2f); return false; }
            Screen here = Scr();
            List<Screen> others = new List<Screen>();
            foreach (Screen sc in all) if (sc.DeviceName != here.DeviceName) others.Add(sc);
            Screen dest = others[rnd.Next(others.Count)];
            Rectangle db = dest.Bounds;
            goal = Goal.Travel;
            goalX = Rand(db.Left + 120 * S, Math.Max(db.Left + 121 * S, db.Right - 120 * S));
            state = PetState.Walk; stateTime = 0; hasAim = false; weapon = Weapon.AK;
            string[] lines = { "¡Misión: invadir la otra pantalla!", "Me voy de expedición.", "¡Hay territorio sin vigilar ahí!" };
            if (fromUser) SayAlways(Pick(lines), 2.5f); else Say(Pick(lines), 2.5f);
            return true;
        }

        void BeginClimb()
        {
            Rectangle sb = ceilScr;
            if (goal == Goal.ClimbWindow)
            {
                Native.RECT r;
                if (!ValidClimbWindow(goalHwnd, out r)) { goal = Goal.None; NextIdle(1f); Say("Bah, ya no está.", 2f); return; }
                if (climbSide < 0) { orient = Orient.WallRight; px = r.Left; }
                else { orient = Orient.WallLeft; px = r.Right; }
                climbTargetY = r.Top + 12 * S;
                platRect = r;
            }
            else
            {
                if (climbSide < 0) { orient = Orient.WallLeft; px = sb.Left + 2 * S; }
                else { orient = Orient.WallRight; px = sb.Right - 2 * S; }
                climbTargetY = ceilTop + 60 * S;
            }
            facing = orient == Orient.WallRight ? 1 : -1;
            py = Ground() - 45 * S;
            state = PetState.Climb; stateTime = 0;
        }

        void FinishClimb()
        {
            Rectangle sb = ceilScr;
            if (goal == Goal.ClimbWindow)
            {
                orient = Orient.Floor; surf = Surf.WindowTop; platHwnd = goalHwnd;
                py = platRect.Top;
                px = climbSide < 0 ? platRect.Left + 35 * S : platRect.Right - 35 * S;
                moveDir = climbSide < 0 ? 1 : -1; facing = moveDir;
                platTime = 0; platDur = Rand(20f, 40f);
                Say("¡Vistas privilegiadas!", 2.5f);
            }
            else
            {
                orient = Orient.Ceiling; surf = Surf.Ceiling;
                py = ceilTop;
                px = climbSide < 0 ? sb.Left + 60 * S : sb.Right - 60 * S;
                moveDir = climbSide < 0 ? 1 : -1; facing = -moveDir;
                platTime = 0; platDur = Rand(15f, 30f);
                Say("Patrulla del techo.", 2.5f);
            }
            goal = Goal.None;
            NextIdle(1f);
        }

        void LeavePlatform()
        {
            if (surf == Surf.Ceiling)
            {
                py += 140 * S;
                BeginFall(0, 0);
                Say("¡GERÓNIMOOO!", 2.5f);
            }
            else
            {
                BeginFall(moveDir * 140f * S, -300f * S);
                Say("¡Allá voy!", 2f);
            }
        }

        void BeginFall(float fvx, float fvy)
        {
            orient = Orient.Floor; surf = Surf.Ground; platHwnd = IntPtr.Zero; goal = Goal.None;
            state = PetState.Fall; stateTime = 0; vx = fvx; vy = fvy;
            chute = false; chuteArmed = Ground() - py > 280 * S; hasAim = false;
            if (weapon != Weapon.AK) weapon = Weapon.AK;
        }

        void CheckPlatform()
        {
            if (surf != Surf.WindowTop && !(state == PetState.Climb && goal == Goal.ClimbWindow)) return;
            if (state == PetState.Drag || state == PetState.Fall || state == PetState.Crazy) return;
            IntPtr h = surf == Surf.WindowTop ? platHwnd : goalHwnd;
            Native.RECT r;
            bool ok = h != IntPtr.Zero && Native.IsWindowVisible(h) && !Native.IsIconic(h) && Native.GetWindowRect(h, out r)
                      && Math.Abs(r.Top - platRect.Top) <= 3 && Math.Abs(r.Left - platRect.Left) <= 3 && Math.Abs(r.Right - platRect.Right) <= 3;
            if (!ok)
            {
                BeginFall(0, 0);
                Say("¡Eh, que me tiras!", 2.5f);
            }
        }

        // ================================ bucle ================================
        void OnTick(object sender, EventArgs e)
        {
            if (IsDisposed || Disposing) return;
            try { TickInner(); }
            catch (Exception ex) { Log.W("ERROR en tick: " + ex); }
        }

        void TickInner()
        {
            float now = (float)clock.Elapsed.TotalSeconds;
            float dt = Math.Min(0.05f, now - lastTime);
            lastTime = now;
            t += dt;
            tick++;

            Step(dt);

            envAcc += dt; musicAcc += dt;
            if (musicAcc >= 0.2f) { PollMusic(musicAcc); musicAcc = 0; }
            if (envAcc >= 0.5f) { CheckEnvironment(envAcc); envAcc = 0; }
            int wantInterval = hiddenFS ? 250 : 33;   // en pantalla completa casi no gasta
            if (timer.Interval != wantInterval) timer.Interval = wantInterval;

            if (tick % 3 == 0) StepExtras(dt * 3);
            if (IsDisposed || Disposing) return;   // se ha cerrado para actualizarse

            if (!hiddenFS)
            {
                // quieto o dormido: se redibuja a ~15 fps; en movimiento, a tope
                bool calmPose = (state == PetState.Idle || state == PetState.Sleep) && squash <= 0 && Math.Abs(lean) < 0.05f;
                bool away = calmPose && Native.IdleMs() > 180000;   // no estas usando el PC
                int every = away ? 15 : 4;
                if (!calmPose || tick % every == 0 || speech != lastDrawnSpeech) Render();

                bool need = bullets.Count > 0 || holes.Count > 0 || parts.Count > 0 || rings.Count > 0 || popups.Count > 0 ||
                            splats.Count > 0 || blobs.Count > 0 || grenades.Count > 0 || state == PetState.Dodge;
                if (need) overlay.Draw(EffectsBox(), DrawOverlay);
                else if (overlayDirty) overlay.Clear();
                overlayDirty = need;

                if (buddy != null) buddy.Tick(dt);
            }
        }

        void Step(float dt)
        {
            stateTime += dt;
            squash = Math.Max(0, squash - dt * 5f);
            float leanTarget = 0;
            if (state == PetState.Walk) leanTarget = goal == Goal.Travel ? 7f : 4f;
            else if (state == PetState.Trench) leanTarget = trenchPeek ? 8f : -4f;
            lean += (leanTarget - lean) * Math.Min(1f, dt * 8f);
            anger = Math.Max(0, anger - 0.15f * dt);
            if (speechLeft > 0) { speechLeft -= dt; if (speechLeft <= 0) speech = null; }
            if (surf != Surf.Ground) platTime += dt;
            if (musicCooldown > 0) musicCooldown -= dt;

            blinkTimer -= dt;
            if (blinkTimer <= 0) { blinkLeft = 0.12f; blinkTimer = Rand(2f, 5f); }
            if (blinkLeft > 0) blinkLeft -= dt;

            recoil = Math.Max(0, recoil - dt * 9f);
            if (flashLeft > 0) flashLeft -= dt;

            float ground = Ground();

            // al pasar a una pantalla cuyo suelo esta mas abajo, se cae
            if (surf == Surf.Ground && orient == Orient.Floor && ground > py + 12 * S &&
                state != PetState.Fall && state != PetState.Drag && state != PetState.Crazy &&
                state != PetState.Dance && state != PetState.Climb && state != PetState.Dodge)
            {
                Goal keep = goal; float keepX = goalX;
                BeginFall(moveDir * 90f * S, 0);
                goal = keep; goalX = keepX;
                Say("¡Un escalón!", 1.5f);
            }
            // se ha colado por debajo de una pantalla mas alta: lo subimos
            else if (surf == Surf.Ground && orient == Orient.Floor && ground < py - 12 * S &&
                     state != PetState.Fall && state != PetState.Drag && state != PetState.Crazy && state != PetState.Climb)
            {
                py = ground;
            }

            switch (state)
            {
                case PetState.Idle:
                    py = SurfY();
                    if (stateTime >= stateDur) ChooseNext();
                    break;

                case PetState.Walk:
                    py = SurfY();
                    walkPhase += dt * 11f;
                    if (goal != Goal.None)
                    {
                        if (Math.Abs(goalX - px) < 6 * S)
                        {
                            px = goalX;
                            if (goal == Goal.Travel) { goal = Goal.None; NextIdle(2f); Say("Territorio conquistado.", 2.5f); }
                            else if (goal == Goal.Trench) { goal = Goal.None; BeginTrench(); }
                            else BeginClimb();
                            break;
                        }
                        moveDir = goalX < px ? -1 : 1;
                        if (StepUpAhead()) break;
                        px += moveDir * (goal == Goal.Travel ? 170f : 110f) * S * dt;
                    }
                    else
                    {
                        if (StepUpAhead()) break;
                        px += moveDir * 75f * S * dt;
                        if (px < SurfMin()) { px = SurfMin(); moveDir = 1; }
                        if (px > SurfMax()) { px = SurfMax(); moveDir = -1; }
                        if (stateTime >= stateDur) NextIdle(Rand(1.5f, 4f));
                    }
                    facing = orient == Orient.Ceiling ? -moveDir : moveDir;
                    break;

                case PetState.Shoot:
                    py = SurfY();
                    if (hasAim) FaceToward(aimTarget.X);
                    if (shotsLeft > 0)
                    {
                        shotTimer -= dt;
                        if (shotTimer <= 0) { FireOne(); shotsLeft--; ammo--; shotTimer = 0.09f; }
                    }
                    else
                    {
                        afterBurst -= dt;
                        if (afterBurst <= 0) { if (ammo <= 0) StartReload(); else NextIdle(Rand(1.5f, 3f)); }
                    }
                    break;

                case PetState.Reload:
                    py = SurfY();
                    if (stateTime >= stateDur) { ammo = 30; NextIdle(1f); Say("¡Listo!", 1.2f); }
                    break;

                case PetState.Guard:
                    py = SurfY();
                    if (stateTime >= stateDur)
                    {
                        if (fireAfterGuard) { state = PetState.Idle; StartBurstAt(true, aimTarget); }
                        else NextIdle(1.5f);
                    }
                    break;

                case PetState.Dance:
                    vy += 1700f * S * dt;
                    py += vy * dt;
                    if (py >= ground)
                    {
                        py = ground;
                        squash = Math.Max(squash, 0.45f);
                        if (hopsLeft > 0) { vy = -420f * S; hopsLeft--; facing = -facing; moveDir = facing; }
                        else { vy = 0; NextIdle(Rand(1.5f, 3f)); }
                    }
                    break;

                case PetState.Trench:
                    {
                        py = SurfY();
                        facing = trenchSide; moveDir = trenchSide;
                        float edge = TrenchEdge();
                        float target = trenchPeek ? edge + trenchSide * 24 * S : edge - trenchSide * 30 * S;
                        float stepMax = 230f * S * dt;
                        px += Math.Max(-stepMax, Math.Min(stepMax, target - px));
                        walkPhase += Math.Abs(target - px) > 2 ? dt * 11f : 0;
                        trenchSwitch -= dt;
                        if (trenchSwitch <= 0)
                        {
                            trenchPeek = !trenchPeek;
                            trenchSwitch = trenchPeek ? Rand(1.2f, 2.2f) : Rand(1.5f, 3f);
                            if (trenchPeek)
                            {
                                if (ammo <= 0) { ammo = 30; trenchPeek = false; Say("¡Recargando a cubierto!", 1.6f); }
                                else if (!Calm() && shootMul > 0.01f && rnd.NextDouble() < 0.75)
                                {
                                    shotsLeft = Math.Min(ammo, (int)Math.Max(2, rnd.Next(3, 8) * Math.Min(1.5f, shootMul)));
                                    trenchShot = 0.25f;
                                    if (SoundOK()) PlayBurst(shotsLeft, 0.09);
                                }
                                if (rnd.NextDouble() < 0.4) Say(Pick(TRENCH_LINES), 1.8f);
                            }
                        }
                        if (trenchPeek && shotsLeft > 0)
                        {
                            trenchShot -= dt;
                            if (trenchShot <= 0) { FireOne(); shotsLeft--; ammo--; trenchShot = 0.09f; }
                        }
                        if (stateTime >= stateDur && trenchPeek)
                        {
                            px = edge + trenchSide * 24 * S;
                            NextIdle(1.5f); Say("Fin de la guardia en la trinchera.", 2.5f);
                        }
                        else if (stateTime >= stateDur + 4f) { trenchPeek = true; }
                    }
                    break;

                case PetState.MusicDance:
                    py = SurfY();
                    if (((int)(stateTime / 1.1f)) % 2 == 0) facing = moveDir; else facing = -moveDir;
                    if (musicOff > 3f) { NextIdle(1.5f); Say("Se acabó la fiesta.", 2f); musicCooldown = 30f; }
                    else if (stateTime >= stateDur) { NextIdle(2f); Say("Me canso. Sigo vigilando.", 2.5f); musicCooldown = 90f; }
                    break;

                case PetState.Squats:
                    py = SurfY();
                    squatPhase += dt * 3.2f;
                    if (squatPhase >= (float)(2 * Math.PI))
                    {
                        squatPhase -= (float)(2 * Math.PI);
                        squatReps++;
                        Say("¡" + squatReps + "!", 0.8f);
                    }
                    if (stateTime >= stateDur) { NextIdle(2f); Say("Hecho. Ahora mírame con respeto.", 2.5f); }
                    break;

                case PetState.Bazooka:
                    py = SurfY();
                    if (shotsLeft > 0 && stateTime >= 0.9f) { FireBlob(); shotsLeft = 0; }
                    if (stateTime >= 1.9f) { weapon = Weapon.AK; NextIdle(1.5f); }
                    break;

                case PetState.Throw:
                    py = SurfY();
                    if (shotsLeft > 0 && stateTime >= 0.45f) { ThrowGrenade(); shotsLeft = 0; }
                    if (stateTime >= 1.0f) NextIdle(1.5f);
                    break;

                case PetState.Confetti:
                    py = SurfY();
                    if (parts.Count < 1400) for (int i = 0; i < 7; i++) SpawnConfetti();
                    if (stateTime >= stateDur)
                    {
                        weapon = Weapon.AK; NextIdle(1.5f);
                        Say("¡FELICIDADES! No sé por qué, pero felicidades.", 3f);
                    }
                    break;

                case PetState.Climb:
                    py -= 70f * S * dt;
                    walkPhase += dt * 9f;
                    if (py <= climbTargetY) FinishClimb();
                    break;

                case PetState.Drag:
                    {
                        Point c = Cursor.Position;
                        float nx = c.X - dragOffX, ny = c.Y - dragOffY;
                        vx = vx * 0.6f + (nx - px) / Math.Max(dt, 0.001f) * 0.4f;
                        vy = vy * 0.6f + (ny - py) / Math.Max(dt, 0.001f) * 0.4f;
                        px = nx; py = Math.Min(ny, ground);
                        if (!mouseDownLeft || (Control.MouseButtons & MouseButtons.Left) == 0) Drop();
                    }
                    break;

                case PetState.Fall:
                    if (chuteArmed && !chute && vy > 0 && ground - py > 120 * S) { chute = true; Say("¡PARACAÍDAS!", 1.5f); }
                    if (chute)
                    {
                        vy += (110f * S - vy) * Math.Min(1f, 4f * dt);
                        vx += ((float)Math.Sin(t * 1.3f) * 70f * S - vx) * Math.Min(1f, 2f * dt);
                    }
                    else
                    {
                        vy += 1900f * S * dt;
                        vx *= (1f - 0.8f * dt);
                    }
                    px += vx * dt; py += vy * dt;
                    if (px < MinX()) { px = MinX(); vx = -vx * 0.5f; }
                    if (px > MaxX()) { px = MaxX(); vx = -vx * 0.5f; }
                    if (py >= ground)
                    {
                        py = ground;
                        squash = Math.Max(squash, Math.Min(1f, vy / (1400f * S)));
                        if (chute) { chute = false; chuteArmed = false; vy = 0; vx = 0; NextIdle(1.5f); Say("Aterrizaje perfecto.", 2.5f); }
                        else if (vy > 650f * S) { vy = -vy * 0.33f; vx *= 0.6f; Say(Pick(FALL_LINES), 2f); }
                        else
                        {
                            vy = 0; vx = 0;
                            if (goal == Goal.Travel) { state = PetState.Walk; stateTime = 0; }
                            else NextIdle(Rand(1f, 2.5f));
                        }
                    }
                    break;

                case PetState.Crazy:
                    crazyAngle += dt * 620f;
                    vy += 1700f * S * dt;
                    py += vy * dt; px += vx * dt;
                    if (px < MinX()) { px = MinX(); vx = Math.Abs(vx); }
                    if (px > MaxX()) { px = MaxX(); vx = -Math.Abs(vx); }
                    if (py >= ground)
                    {
                        py = ground;
                        vy = -Rand(280f, 560f) * S;
                        vx = Rand(-380f, 380f) * S;
                        facing = -facing;
                    }
                    shotTimer -= dt;
                    if (shotTimer <= 0) { FireOne(); shotTimer = 0.04f; }
                    crazySoundTimer -= dt;
                    if (crazySoundTimer <= 0) { if (soundOn) PlayBurst(28, 0.045); crazySoundTimer = 28 * 0.045f; }
                    crazyTalkTimer -= dt;
                    if (crazyTalkTimer <= 0) { SayAlways(Pick(CRAZY_LINES), 1.6f); crazyTalkTimer = 1.7f; }
                    if (stateTime >= stateDur)
                    {
                        state = PetState.Fall; stateTime = 0; vx = 0; chute = false; chuteArmed = false;
                        angry = false; ammo = 30;
                        SayAlways("...Perdón. Me he dejado llevar.", 3.5f);
                    }
                    break;

                case PetState.Dodge:
                    py = ground;
                    {
                        Point c = Cursor.Position;
                        aimTarget = new PointF(c.X, c.Y);
                        FaceToward(c.X);
                    }
                    if (!dodgeRunning)
                    {
                        float prev = dodgeCountdown;
                        dodgeCountdown -= dt;
                        if (Math.Ceiling(prev) != Math.Ceiling(dodgeCountdown) && dodgeCountdown > 0 && dodgeCountdown < 3.01f)
                            SayAlways(((int)Math.Ceiling(dodgeCountdown)) + "...", 0.9f);
                        if (dodgeCountdown <= 0) { dodgeRunning = true; dodgeTime = 0; SayAlways("¡YA!", 1f); }
                    }
                    else
                    {
                        dodgeTime += dt;
                        dodgeShot -= dt;
                        if (dodgeShot <= 0) { FireGame(); dodgeShot = Math.Max(0.11f, 0.55f - dodgeTime * 0.012f); }
                    }
                    break;

                case PetState.Sleep:
                    if (surf == Surf.Ground) py = ground; else py = SurfY();
                    if (stateTime >= stateDur) { NextIdle(1f); Say("¿Eh? ¿Qué me he perdido?", 2.5f); }
                    break;
            }

            CheckPlatform();
            UpdateWorld(dt);
        }

        // ============================== disparos ==============================
        void FireOne()
        {
            diary.Shots++;
            recoil = 1f; flashLeft = 0.05f;
            PointF muzzle = GunPoint(new PointF(88, -5));
            PointF back = GunPoint(new PointF(40, -5));
            float dx = muzzle.X - back.X, dy = muzzle.Y - back.Y;
            float len = (float)Math.Sqrt(dx * dx + dy * dy);
            if (len < 0.001f) { dx = facing; dy = 0; len = 1; }
            dx /= len; dy /= len;
            bool crazy = state == PetState.Crazy;
            float spread = crazy ? Rand(-0.09f, 0.09f) : Rand(-0.04f, 0.04f);
            float speed = (crazy ? 1300f : 1500f) * S;
            AddBullet(muzzle.X, muzzle.Y, (dx - dy * spread) * speed, (dy + dx * spread) * speed,
                (crazy && rnd.NextDouble() < 0.55) ? Rand(120f, 1300f) * S : -1f, false);
            EjectCasing();
        }

        void FireGame()
        {
            diary.Shots++;
            recoil = 1f; flashLeft = 0.05f;
            PointF muzzle = GunPoint(new PointF(88, -5));
            Point c = Cursor.Position;
            float dx = c.X - muzzle.X, dy = c.Y - muzzle.Y;
            float len = (float)Math.Sqrt(dx * dx + dy * dy);
            if (len < 1) { dx = facing; dy = 0; len = 1; }
            dx /= len; dy /= len;
            float spread = Rand(-0.025f, 0.025f);
            float speed = Math.Min(1700f, 800f + dodgeTime * 25f) * S;
            AddBullet(muzzle.X, muzzle.Y, (dx - dy * spread) * speed, (dy + dx * spread) * speed, -1f, true);
            EjectCasing();
            if (SoundOK()) PlayBurst(1, 0.1);
        }

        void AddBullet(float x, float y, float bvx, float bvy, float stop, bool game)
        {
            Bullet b = new Bullet();
            b.X = x; b.Y = y; b.PX = x; b.PY = y; b.VX = bvx; b.VY = bvy; b.StopDist = stop; b.Game = game;
            bullets.Add(b);
        }

        void EjectCasing()
        {
            PointF port = GunPoint(new PointF(14, -8));
            PointF up = PetToScreen(new PointF(0, -1));
            float ux = (up.X - px) / S, uy = (up.Y - py) / S;   // direccion "arriba" del cacahuete
            Part p = AddPart(K_CASING, port.X, port.Y, 0, 0, 1.6f, 7 * S, Color.FromArgb(212, 160, 23));
            float back = Rand(120f, 260f) * S, lift = Rand(350f, 520f) * S;
            PointF fwd = PetToScreen(new PointF(1, 0));
            float fx = (fwd.X - px) / S, fy = (fwd.Y - py) / S;
            p.VX = -fx * back + ux * lift; p.VY = -fy * back + uy * lift;
            p.VR = Rand(-900f, 900f);
        }

        void FireBlob()
        {
            recoil = 2f; flashLeft = 0.09f;
            PointF muzzle = GunPoint(new PointF(84, -4));
            PointF back = GunPoint(new PointF(20, -4));
            float dx = muzzle.X - back.X, dy = muzzle.Y - back.Y;
            float len = (float)Math.Sqrt(dx * dx + dy * dy);
            if (len < 0.001f) { dx = facing; dy = 0; len = 1; }
            dx /= len; dy /= len;
            Blob b = new Blob();
            b.X = muzzle.X; b.Y = muzzle.Y; b.VX = dx * 950f * S; b.VY = dy * 950f * S;
            b.StopDist = Rand(450f, 1300f) * S;
            blobs.Add(b);
            PointF rear = GunPoint(new PointF(-50, -4));
            for (int i = 0; i < 7; i++)
                AddPart(K_SMOKE, rear.X, rear.Y, -dx * Rand(80f, 200f) * S + Rand(-40f, 40f) * S, -dy * Rand(80f, 200f) * S + Rand(-40f, 40f) * S,
                    Rand(0.6f, 1.1f), Rand(8f, 14f) * S, Color.FromArgb(200, 200, 200));
            if (SoundOK()) PlayThump();
        }

        void ThrowGrenade()
        {
            PointF hand = PetToScreen(new PointF(30, -80));
            Grenade gr = new Grenade();
            gr.X = hand.X; gr.Y = hand.Y;
            int dir = orient == Orient.Ceiling ? -facing : facing;
            gr.VX = dir * Rand(380f, 750f) * S;
            gr.VY = orient == Orient.Ceiling ? Rand(100f, 300f) * S : -Rand(500f, 800f) * S;
            gr.VR = Rand(-720f, 720f); gr.Fuse = 1.6f;
            grenades.Add(gr);
        }

        void SpawnConfetti()
        {
            PointF muzzle = GunPoint(new PointF(74, -5));
            PointF back = GunPoint(new PointF(30, -5));
            float dx = muzzle.X - back.X, dy = muzzle.Y - back.Y;
            float len = (float)Math.Sqrt(dx * dx + dy * dy);
            if (len < 0.001f) { dx = facing; dy = 0; len = 1; }
            dx /= len; dy /= len;
            double a = Math.Atan2(dy, dx) + Rand(-0.35f, 0.35f);
            float sp = Rand(450f, 950f) * S;
            Color[] pal = { Color.FromArgb(244, 67, 54), Color.FromArgb(255, 193, 7), Color.FromArgb(76, 175, 80),
                            Color.FromArgb(33, 150, 243), Color.FromArgb(156, 39, 176), Color.FromArgb(255, 105, 180), Color.White };
            Part p = AddPart(K_CONFETTI, muzzle.X, muzzle.Y, (float)Math.Cos(a) * sp, (float)Math.Sin(a) * sp,
                Rand(5f, 8f), Rand(5f, 9f) * S, pal[rnd.Next(pal.Length)]);
            p.VR = Rand(-600f, 600f); p.Phase = Rand(0f, 6.28f);
        }

        void Explode(float x, float y)
        {
            AddRing(x, y, 120 * S, 0.45f);
            AddPopup(x, y - 40 * S, "¡BUM!", Color.FromArgb(255, 152, 0));
            for (int i = 0; i < 10; i++)
                AddPart(K_SMOKE, x + Rand(-20f, 20f) * S, y + Rand(-20f, 10f) * S, Rand(-80f, 80f) * S, -Rand(20f, 120f) * S,
                    Rand(0.8f, 1.6f), Rand(12f, 22f) * S, Color.FromArgb(120, 120, 120));
            for (int i = 0; i < 20; i++)
            {
                double a = Rand(0f, 6.28f);
                float sp = Rand(250f, 700f) * S;
                Part p = AddPart(K_FRAG, x, y, (float)Math.Cos(a) * sp, (float)Math.Sin(a) * sp - 200 * S, Rand(1.5f, 2.5f), Rand(5f, 8f) * S,
                    i % 2 == 0 ? Color.FromArgb(30, 30, 30) : Color.FromArgb(235, 235, 235));
                p.VR = Rand(-900f, 900f);
            }
            if (SoundOK()) PlayBoom();
            // si le pilla cerca, sale volando
            float dxp = px - x, dyp = (py - 60 * S) - y;
            if (dxp * dxp + dyp * dyp < (160 * S) * (160 * S) && state != PetState.Drag && state != PetState.Crazy && state != PetState.Dodge)
            {
                BeginFall((dxp >= 0 ? 1 : -1) * 350f * S, -750f * S);
                SayAlways("¡MIS CÁSCARAS!", 2f);
            }
        }

        void MakeSplat(float x, float y)
        {
            Splat s = new Splat();
            s.X = x; s.Y = y; s.MaxLife = 9f; s.Life = 9f;
            int n = 8;
            s.BX = new float[n]; s.BY = new float[n]; s.BR = new float[n];
            s.BX[0] = 0; s.BY[0] = 0; s.BR[0] = 26 * S;
            for (int i = 1; i < n; i++)
            {
                double a = Rand(0f, 6.28f); float d = Rand(18f, 46f) * S;
                s.BX[i] = (float)Math.Cos(a) * d; s.BY[i] = (float)Math.Sin(a) * d; s.BR[i] = Rand(5f, 14f) * S;
            }
            s.DX = new float[4]; s.DL = new float[4];
            for (int i = 0; i < 4; i++) { s.DX[i] = Rand(-20f, 20f) * S; s.DL[i] = Rand(25f, 70f) * S; }
            splats.Add(s);
            if (splats.Count > 25) splats.RemoveAt(0);
            AddPopup(x, y - 45 * S, "¡SPLAT!", Color.FromArgb(198, 134, 66));
            for (int i = 0; i < 10; i++)
            {
                double a = Rand(0f, 6.28f); float sp = Rand(150f, 400f) * S;
                AddPart(K_DROP, x, y, (float)Math.Cos(a) * sp, (float)Math.Sin(a) * sp - 150 * S, Rand(2f, 3.5f), Rand(4f, 7f) * S, Color.FromArgb(141, 85, 36));
            }
        }

        void AddHole(float x, float y)
        {
            Hole h = new Hole();
            h.X = x; h.Y = y; h.Life = Rand(6f, 9f);
            int n = rnd.Next(5, 9);
            h.Ang = new float[n]; h.Len = new float[n];
            for (int i = 0; i < n; i++)
            {
                h.Ang[i] = (float)(i * 2 * Math.PI / n + Rand(-0.3f, 0.3f));
                h.Len[i] = Rand(14f, 42f) * S;
            }
            holes.Add(h);
            if (holes.Count > 80) holes.RemoveAt(0);
        }

        Part AddPart(int kind, float x, float y, float pvx, float pvy, float life, float size, Color col)
        {
            Part p = new Part();
            p.Kind = kind; p.X = x; p.Y = y; p.VX = pvx; p.VY = pvy; p.Life = life; p.Size = size; p.Col = col;
            parts.Add(p);
            return p;
        }

        void AddRing(float x, float y, float maxR, float life)
        {
            Ring r = new Ring(); r.X = x; r.Y = y; r.MaxR = maxR; r.Life = life; r.MaxLife = life; rings.Add(r);
        }

        void AddPopup(float x, float y, string text, Color col)
        {
            Popup p = new Popup(); p.X = x; p.Y = y; p.Text = text; p.Col = col; p.Life = 1.1f; p.MaxLife = 1.1f; popups.Add(p);
        }

        void UpdateWorld(float dt)
        {
            float ground = Ground();
            Rectangle area = overlay.Area;
            area.Inflate((int)(60 * S), (int)(60 * S));
            Point cur = Cursor.Position;

            for (int i = bullets.Count - 1; i >= 0; i--)
            {
                Bullet b = bullets[i];
                b.PX = b.X; b.PY = b.Y;
                float stepX = b.VX * dt, stepY = b.VY * dt;
                b.X += stepX; b.Y += stepY;
                b.Dist += (float)Math.Sqrt(stepX * stepX + stepY * stepY);
                if (b.Game && dodgeRunning && state == PetState.Dodge && SegDist(b.PX, b.PY, b.X, b.Y, cur.X, cur.Y) < 9 * S)
                {
                    bullets.RemoveAt(i);
                    DodgeOver(cur.X, cur.Y);
                    continue;
                }
                if (b.StopDist > 0 && b.Dist >= b.StopDist) { AddHole(b.X, b.Y); bullets.RemoveAt(i); continue; }
                if (!area.Contains((int)b.X, (int)b.Y)) bullets.RemoveAt(i);
            }

            for (int i = holes.Count - 1; i >= 0; i--) { holes[i].Life -= dt; if (holes[i].Life <= 0) holes.RemoveAt(i); }
            for (int i = splats.Count - 1; i >= 0; i--) { splats[i].Life -= dt; if (splats[i].Life <= 0) splats.RemoveAt(i); }
            for (int i = rings.Count - 1; i >= 0; i--) { rings[i].Life -= dt; if (rings[i].Life <= 0) rings.RemoveAt(i); }
            for (int i = popups.Count - 1; i >= 0; i--) { popups[i].Life -= dt; popups[i].Y -= 30 * S * dt; if (popups[i].Life <= 0) popups.RemoveAt(i); }

            for (int i = blobs.Count - 1; i >= 0; i--)
            {
                Blob b = blobs[i];
                b.VY += 250f * S * dt;
                float sx = b.VX * dt, sy = b.VY * dt;
                b.X += sx; b.Y += sy; b.Dist += (float)Math.Sqrt(sx * sx + sy * sy);
                if (b.Dist >= b.StopDist || b.Y >= ground - 4 * S || !area.Contains((int)b.X, (int)b.Y))
                {
                    MakeSplat(b.X, Math.Min(b.Y, ground - 20 * S));
                    blobs.RemoveAt(i);
                }
            }

            Rectangle sb = overlay.Area;
            for (int i = grenades.Count - 1; i >= 0; i--)
            {
                Grenade g = grenades[i];
                g.VY += 1500f * S * dt;
                g.X += g.VX * dt; g.Y += g.VY * dt; g.Rot += g.VR * dt; g.Fuse -= dt;
                if (g.Y >= ground - 4 * S) { g.Y = ground - 4 * S; g.VY = -Math.Abs(g.VY) * 0.45f; g.VX *= 0.7f; g.VR *= 0.7f; }
                if (g.X < sb.Left + 5) { g.X = sb.Left + 5; g.VX = Math.Abs(g.VX) * 0.6f; }
                if (g.X > sb.Right - 5) { g.X = sb.Right - 5; g.VX = -Math.Abs(g.VX) * 0.6f; }
                if (g.Fuse <= 0) { Explode(g.X, g.Y); grenades.RemoveAt(i); }
            }

            for (int i = parts.Count - 1; i >= 0; i--)
            {
                Part p = parts[i];
                p.Life -= dt;
                if (p.Life <= 0) { parts.RemoveAt(i); continue; }
                switch (p.Kind)
                {
                    case K_SMOKE:
                        p.X += p.VX * dt; p.Y += p.VY * dt; p.VX *= (1f - dt); p.VY *= (1f - dt); p.Size += 40f * S * dt;
                        break;
                    case K_CONFETTI:
                        if (!p.Grounded)
                        {
                            p.VX *= (1f - 1.8f * dt);
                            p.VY += 700f * S * dt;
                            if (p.VY > 130f * S) p.VY = 130f * S;
                            p.X += (p.VX + (float)Math.Sin(t * 4f + p.Phase) * 40f * S) * dt;
                            p.Y += p.VY * dt;
                            p.Rot += p.VR * dt;
                            if (p.Y >= ground - 2 * S) { p.Y = ground - 2 * S; p.Grounded = true; }
                        }
                        break;
                    default:
                        if (!p.Grounded)
                        {
                            p.VY += 1500f * S * dt;
                            p.X += p.VX * dt; p.Y += p.VY * dt; p.Rot += p.VR * dt;
                            if (p.Y > ground - p.Size * 0.4f)
                            {
                                p.Y = ground - p.Size * 0.4f;
                                if (p.Kind == K_DROP || Math.Abs(p.VY) < 60 * S) { p.Grounded = true; p.VX = 0; p.VY = 0; }
                                else { p.VY = -p.VY * 0.35f; p.VX *= 0.6f; p.VR *= 0.5f; }
                            }
                        }
                        break;
                }
            }
            if (parts.Count > 1600) parts.RemoveRange(0, parts.Count - 1600);
        }

        static float SegDist(float x1, float y1, float x2, float y2, float x, float y)
        {
            float dx = x2 - x1, dy = y2 - y1;
            float l2 = dx * dx + dy * dy;
            float k = l2 < 0.0001f ? 0 : Math.Max(0, Math.Min(1, ((x - x1) * dx + (y - y1) * dy) / l2));
            float cx = x1 + k * dx - x, cy = y1 + k * dy - y;
            return (float)Math.Sqrt(cx * cx + cy * cy);
        }

        // ============================ geometria del arma ============================
        float BodyBob()
        {
            if (state == PetState.Walk || state == PetState.Climb) return -Math.Abs((float)Math.Sin(walkPhase)) * 3f;
            if (state == PetState.Sleep) return (float)Math.Sin(t * 1.6f) * 1.2f;
            if (state == PetState.Squats) return (1f - (float)Math.Cos(squatPhase)) * 0.5f * 16f;
            if (state == PetState.MusicDance) return -musicLevel * 22f - Math.Abs((float)Math.Sin(t * 8f)) * 4f;
            return (float)Math.Sin(t * 3f) * 1.2f;
        }

        PointF GunAnchor()
        {
            return new PointF(-4f - recoil * 5f, -56f + BodyBob() + (weapon == Weapon.Bazooka ? -20f : 0f));
        }

        float AimAngle()
        {
            PointF a = PetToScreen(GunAnchor());
            float dx = aimTarget.X - a.X, dy = aimTarget.Y - a.Y;
            double r = CurrentAngle() * Math.PI / 180.0;
            float lx = (float)(dx * Math.Cos(r) + dy * Math.Sin(r));
            float ly = (float)(-dx * Math.Sin(r) + dy * Math.Cos(r));
            lx *= facing;
            float deg = (float)(Math.Atan2(ly, lx) * 180.0 / Math.PI);
            return Math.Max(-75f, Math.Min(75f, deg));
        }

        float GunAngle()
        {
            switch (state)
            {
                case PetState.Crazy: return crazyAngle % 360f;
                case PetState.Climb: return 40f;
                case PetState.Drag:
                case PetState.Fall: return 35f + (float)Math.Sin(t * 10f) * 8f;
                case PetState.Sleep: return 28f;
                case PetState.Reload: return 30f + (float)Math.Sin(t * 20f) * 4f;
                case PetState.Dance: return -20f + (float)Math.Sin(t * 14f) * 15f;
                case PetState.MusicDance: return -15f + (float)Math.Sin(t * 8f) * 20f;
                case PetState.Squats: return 20f;
                case PetState.Throw: return 35f;
                case PetState.Confetti: return -12f + (float)Math.Sin(stateTime * 5f) * 26f;
                case PetState.Bazooka: return -8f - recoil * 6f;
            }
            if (hasAim && (state == PetState.Shoot || state == PetState.Guard || state == PetState.Dodge)) return AimAngle() - recoil * 4f;
            return -recoil * 7f;
        }

        Matrix GunMatrix()
        {
            PointF a = GunAnchor();
            Matrix m = new Matrix();
            m.Translate(a.X, a.Y);
            m.Rotate(GunAngle());
            return m;
        }

        PointF GunPoint(PointF gunLocal)
        {
            if (sprites != null)
            {
                string fn = SpriteFrame();
                PointF mz = SpriteSet.Muzzle(fn);
                float bob = state == PetState.Squats ? 0 : BodyBob();
                PointF[] q = { new PointF(mz.X + (gunLocal.X - 88f) - recoil * 3f, mz.Y + (gunLocal.Y + 5f) + bob) };
                float rot = SpriteAimRot();
                if (rot != 0)
                    using (Matrix m = new Matrix())
                    {
                        m.RotateAt(rot, new PointF(0, -70 + bob));
                        m.TransformPoints(q);
                    }
                return PetToScreen(q[0]);
            }
            PointF[] p = { gunLocal };
            using (Matrix m = GunMatrix()) m.TransformPoints(p);
            return PetToScreen(p[0]);
        }

        // ================================ raton ================================
        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                mouseDownLeft = true; dragging = false;
                downX = Cursor.Position.X; downY = Cursor.Position.Y;
                lastInteraction = t;
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (mouseDownLeft && !dragging && state != PetState.Dodge && state != PetState.Crazy)
            {
                Point c = Cursor.Position;
                if (Math.Abs(c.X - downX) + Math.Abs(c.Y - downY) > 6)
                {
                    dragging = true;
                    if (orient == Orient.Ceiling) py += 140 * S;
                    orient = Orient.Floor; surf = Surf.Ground; platHwnd = IntPtr.Zero; goal = Goal.None;
                    chute = false; hasAim = false; weapon = Weapon.AK;
                    state = PetState.Drag; stateTime = 0; vx = 0; vy = 0;
                    dragOffX = downX - px; dragOffY = downY - py;
                    SayAlways(Pick(DRAG_LINES), 2f);
                }
            }
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                bool wasDrag = dragging;
                mouseDownLeft = false; dragging = false;
                lastInteraction = t;
                if (wasDrag) Drop();
                else if (state == PetState.Sleep) { WakeUp(); StartBurstAt(true, Cursor.Position); }
                else if (CanAct())
                {
                    diary.Pokes++;
                    anger += 1f;
                    if (anger >= 2.6f) { anger = 0; StartCrazy(); SayAlways("¡¡ME HABÉIS ENFADADO!!", 1.6f); }
                    else
                    {
                        StartBurstAt(true, Cursor.Position);
                        if (rnd.NextDouble() < 0.5) SayAlways(Pick(POKE_LINES), 2f);
                    }
                }
            }
            else if (e.Button == MouseButtons.Right)
            {
                lastInteraction = t;
                menu.Show(Cursor.Position);
            }
            base.OnMouseUp(e);
        }

        void Drop()
        {
            mouseDownLeft = false; dragging = false;
            float max = 2500f * S;
            float fvx = Math.Max(-max, Math.Min(max, vx));
            float fvy = Math.Max(-max, Math.Min(max, vy));
            BeginFall(fvx, fvy);
        }

        // ======================= entorno: ventanas, horarios =======================
        void CheckEnvironment(float edt)
        {
            bool fs = false;
            IntPtr fg = Native.GetForegroundWindow();
            Native.RECT fr = new Native.RECT();
            bool haveRect = false;
            string cls = "";
            bool mine = fg == Handle || fg == overlay.Handle || (buddy != null && fg == buddy.Handle) ||
                        (settingsWin != null && !settingsWin.IsDisposed && fg == settingsWin.Handle);
            if (fg != IntPtr.Zero && !mine)
            {
                cls = Native.ClassOf(fg);
                haveRect = Native.GetWindowRect(fg, out fr);
                if (haveRect && cls != "Progman" && cls != "WorkerW" && cls != "Shell_TrayWnd")
                {
                    Screen fsScr = Screen.FromHandle(fg);
                    Rectangle sc = fsScr.Bounds;
                    fs = fsScr.DeviceName == Scr().DeviceName && fr.Left <= sc.Left && fr.Top <= sc.Top && fr.Right >= sc.Right && fr.Bottom >= sc.Bottom;
                }
            }
            if (fs && !hiddenFS)
            {
                hiddenFS = true; Native.ShowWindow(Handle, 0); Native.ShowWindow(overlay.Handle, 0);
                if (buddy != null) Native.ShowWindow(buddy.Handle, 0);
                Log.W("oculto por pantalla completa");
            }
            else if (!fs && hiddenFS)
            {
                hiddenFS = false; Native.ShowWindow(overlay.Handle, 4); Native.ShowWindow(Handle, 4);
                if (buddy != null) Native.ShowWindow(buddy.Handle, 4);
            }
            if (!hiddenFS)
            {
                Native.SetWindowPos(overlay.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010);
                if (buddy != null) Native.SetWindowPos(buddy.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010);
                Native.SetWindowPos(Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010); // el cacahuete por encima de los efectos
            }

            bool quiet = Quiet();

            // tiempo sentado / agua (solo cuenta si estas usando el PC)
            if (Native.IdleMs() < 5 * 60 * 1000) { sitTime += edt; waterTime += edt; diary.Active += edt; }
            else sitTime = 0;
            if (!quiet)
            {
                if (sitMin > 0 && sitTime >= sitMin * 60f)
                {
                    sitTime = 0;
                    if (buddy != null) buddy.Say("¡Y yo te lo recuerdo también! Estira las piernas.", 4f);
                    SayAlways("¡Llevas " + (sitMin >= 60 ? (sitMin / 60) + (sitMin >= 120 ? " horas" : " hora") : sitMin + " minutos") + " sentado! ¡EN PIE, SOLDADO! ¡A FORMAR!", 6f);
                }
                else if (waterMin > 0 && waterTime >= waterMin * 60f)
                {
                    waterTime = 0;
                    if (buddy != null) buddy.Say("Agua, agua. Que te veo seco como una pipa.", 5f);
                    else SayAlways("¡Hidratación, soldado! Bebe agua.", 5f);
                }
            }

            // de madrugada te manda a dormir
            int hour = DateTime.Now.Hour;
            if (nightOn && hour >= 1 && hour < 6)
            {
                nightNag -= edt;
                if (nightNag <= 0 && !quiet) { nightNag = 1200f; SayAlways("Son las " + DateTime.Now.ToString("HH:mm") + ". ¡A DORMIR, SOLDADO!", 5f); }
            }

            // la ventana de la trinchera ha cambiado
            if (state == PetState.Trench)
            {
                Native.RECT tr;
                bool okT = Native.IsWindowVisible(trenchHwnd) && !Native.IsIconic(trenchHwnd) && Native.GetWindowRect(trenchHwnd, out tr) &&
                           Math.Abs(tr.Left - trenchRect.Left) <= 3 && Math.Abs(tr.Right - trenchRect.Right) <= 3 && Math.Abs(tr.Bottom - trenchRect.Bottom) <= 3;
                if (!okT) { NextIdle(1.5f); SayAlways("¡Eh! ¡Me han quitado la cobertura!", 2.5f); }
            }

            if (haveRect && !mine) CheckApps(fg);

            // reacciones a ventanas
            reactCooldown -= edt;
            if (!Calm() && reactCooldown <= 0 && haveRect && (state == PetState.Idle || state == PetState.Walk) && goal == Goal.None)
            {
                string title = Native.TitleOf(fg);
                PointF center = new PointF((fr.Left + fr.Right) / 2f, (fr.Top + fr.Bottom) / 2f);
                if (fg != lastFg && (title.IndexOf("Papelera", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                     title.IndexOf("Recycle Bin", StringComparison.OrdinalIgnoreCase) >= 0))
                {
                    StartGuard(center, "¡PAPELERA DETECTADA! ¡EN GUARDIA!", 0.6);
                    reactCooldown = 8f;
                }
                else if (fg == lastFg && fg != platHwnd && cls != "Progman" && cls != "WorkerW")
                {
                    int moved = Math.Abs(fr.Left - lastFgRect.Left) + Math.Abs(fr.Top - lastFgRect.Top);
                    int resized = Math.Abs((fr.Right - fr.Left) - (lastFgRect.Right - lastFgRect.Left)) +
                                  Math.Abs((fr.Bottom - fr.Top) - (lastFgRect.Bottom - lastFgRect.Top));
                    if (moved > 30 * S && resized < 6 && Math.Abs(center.X - px) < 900 * S)
                    {
                        StartGuard(center, Pick(MOVE_LINES), 0.5);
                        reactCooldown = 8f;
                    }
                }
            }
            lastFg = fg;
            if (haveRect) lastFgRect = fr;
        }

        static readonly string[] DEV_APPS = { "devenv", "code", "idea64", "idea", "eclipse", "studio64", "pycharm64", "rider64", "webstorm64", "clion64", "sublime_text", "cursor", "antigravity", "windsurf" };

        void CheckApps(IntPtr fg)
        {
            string proc = fg != lastFg ? Native.ProcessOf(fg) : lastProc;
            string title = Native.TitleOf(fg);
            bool newApp = proc != lastProc, newTitle = title != lastTitle;
            lastProc = proc; lastTitle = title;

            bool dev = Array.IndexOf(DEV_APPS, proc) >= 0;
            bool newFocus = focusOn && dev;
            if (newFocus != focusMode)
            {
                focusMode = newFocus;
                if (focusMode) { Say("Modo concentración. No disparo, lo prometo.", 3f); if (state == PetState.Shoot || state == PetState.Trench) NextIdle(1f); }
                else Say("Fin de la concentración. ¡A filas!", 2.5f);
                return;
            }
            if (!reactApps || Quiet() || !(state == PetState.Idle || state == PetState.Walk || state == PetState.Sleep)) return;

            string key = null, line = null;
            if (newApp)
            {
                switch (proc)
                {
                    case "steam": case "steamwebhelper": key = "steam"; line = "¿Partidita? Yo cubro el flanco."; break;
                    case "epicgameslauncher": key = "epic"; line = "¿Otra vez a por los juegos gratis?"; break;
                    case "spotify": key = "spotify"; line = "¡Pon algo con ritmo, soldado!"; break;
                    case "discord": key = "discord"; line = "¿Reunión de tropas en Discord?"; break;
                    case "whatsapp": case "whatsapp.root": key = "whatsapp"; line = "Saluda de mi parte."; break;
                    case "winword": case "excel": case "powerpnt": key = "office"; line = "Uf, ofimática. Te dejo trabajar."; break;
                    case "taskmgr": key = "taskmgr"; line = "¡Ni se te ocurra cerrarme desde ahí!"; break;
                    case "avpui": case "avp": key = "kaspersky"; line = "Shhh... que no me vea el antivirus."; break;
                }
            }
            if (key == null && newTitle)
            {
                if (title.IndexOf("YouTube", StringComparison.OrdinalIgnoreCase) >= 0) { key = "youtube"; line = "¿YouTube otra vez? Vale, pero uno y a trabajar."; }
                else if (title.IndexOf("TikTok", StringComparison.OrdinalIgnoreCase) >= 0) { key = "tiktok"; line = "TikTok... seguro que es por trabajo, ¿eh?"; }
                else if (title.IndexOf("Netflix", StringComparison.OrdinalIgnoreCase) >= 0) { key = "netflix"; line = "¿Peli? Avísame si sale un cacahuete."; }
            }
            if (key == null) return;
            float lastT;
            if (reacted.TryGetValue(key, out lastT) && t - lastT < 900f) return;
            reacted[key] = t;
            if (state == PetState.Sleep) NextIdle(1f);
            Say(line, 3.5f);
        }

        // cosas que no hace falta revisar en cada fotograma
        void StepExtras(float dt)
        {
            updateCheck += dt;
            if (updateCheck > 5f)
            {
                updateCheck = 0;
                if (Program.NeedsUpdate()) { Program.StartRebuild(); Close(); return; }
            }

            diary.Roll();
            diarySave += dt;
            if (diarySave > 60f) { diarySave = 0; diary.Save(); }

            if (DateTime.Now.Hour >= 22 && Settings.Get("LastSummary", "") != diary.Date && diary.Active > 600f && !Quiet() &&
                (state == PetState.Idle || state == PetState.Walk))
            {
                Settings.Set("LastSummary", diary.Date);
                ShowDiary();
            }

            // charlas con Pipo
            if (replyIn > 0)
            {
                replyIn -= dt;
                if (replyIn <= 0 && buddy != null && pendingReply != null) { buddy.Say(pendingReply, 3.5f); pendingReply = null; }
            }
            if (buddy != null && !Calm() && (state == PetState.Idle || state == PetState.Walk) && surf == Surf.Ground && buddy.CanTalk)
            {
                dialogTimer -= dt;
                if (dialogTimer <= 0)
                {
                    dialogTimer = Rand(90f, 200f);
                    string[] pair = BuddyForm.DIALOGS[rnd.Next(BuddyForm.DIALOGS.Length)];
                    Say(pair[0], 3f);
                    pendingReply = pair[1]; replyIn = 2.8f;
                }
            }
        }

        void PollMusic(float edt)
        {
            audioReinit -= edt;
            if (audioReinit <= 0) { Log.W("audio: iniciando medidor"); bool okA = meter.Init(); audioReinit = 120f; Log.W("audio: " + (okA ? "OK" : "no disponible")); }
            float peak = meter.Peak();
            musicLevel = musicLevel * 0.6f + peak * 0.4f;
            bool own = t - lastSoundTime < 2.5f || state == PetState.Crazy;
            if (peak > 0.03f && !own) { musicOn += edt; musicOff = 0; }
            else { musicOff += edt; if (musicOff > 1.5f) musicOn = 0; }
            if (state != PetState.MusicDance && musicOn > 2.5f && musicCooldown <= 0 && !Calm() &&
                (state == PetState.Idle || state == PetState.Walk) && goal == Goal.None && surf == Surf.Ground)
                StartMusicDance();
        }

        // ================================ dibujo ================================
        void Render()
        {
            float ang = CurrentAngle();
            double rad = ang * Math.PI / 180.0;
            float fwx = AX + (float)(-Math.Sin(rad) * 70), fwy = AY + (float)(Math.Cos(rad) * 70);
            int left = (int)Math.Round(px - fwx * S);
            int top = (int)Math.Round(py - fwy * S);

            // trozo de la ventana que se usa de verdad (cacahuete + bocadillo + zzz)
            float cx = fwx + (float)(Math.Sin(rad) * 75), cy = fwy - (float)(Math.Cos(rad) * 75);
            float R = chute ? 315f : 180f;
            RectangleF lr = RectangleF.FromLTRB(cx - R, cy - R, cx + R, cy + R);
            if (speech != null) lr = RectangleF.Union(lr, BubbleBounds(speech));
            if (state == PetState.Sleep) lr = RectangleF.Union(lr, new RectangleF(AX, orient == Orient.Ceiling ? AY + 60 : AY - 145, 90, 85));
            lr.Intersect(new RectangleF(0, 0, LW, LH));
            Rectangle region = Rectangle.FromLTRB((int)Math.Floor(lr.Left * S), (int)Math.Floor(lr.Top * S),
                                                  Math.Min(W, (int)Math.Ceiling(lr.Right * S) + 1), Math.Min(H, (int)Math.Ceiling(lr.Bottom * S) + 1));
            if (region.Width <= 0 || region.Height <= 0) return;

            using (Graphics g = frame.BeginRegion(W, H, region))
            {
                g.ScaleTransform(S, S);

                // trinchera: la parte que queda "detras" de la ventana no se dibuja
                if (state == PetState.Trench || (state == PetState.Walk && goal == Goal.Trench && trenchInside))
                    using (Region rg = new Region(new RectangleF((trenchRect.Left - left) / S, (trenchRect.Top - top) / S,
                        (trenchRect.Right - trenchRect.Left) / S, (trenchRect.Bottom - trenchRect.Top) / S)))
                        g.ExcludeClip(rg);

                GraphicsState st = g.Save();
                g.TranslateTransform(fwx, fwy);
                g.RotateTransform(ang);
                if (state == PetState.Crazy) g.TranslateTransform(Rand(-2.5f, 2.5f), Rand(-2.5f, 2.5f));
                if (facing < 0) g.ScaleTransform(-1, 1);
                if (Math.Abs(lean) > 0.01f) g.RotateTransform(lean);
                if (squash > 0) g.ScaleTransform(1f + 0.28f * squash, 1f - 0.28f * squash);
                DrawPet(g);
                g.Restore(st);
                g.ResetTransform();
                g.SetClip(region, CombineMode.Replace);
                g.ScaleTransform(S, S);

                if (state == PetState.Sleep) DrawZzz(g);
                if (speech != null) DrawBubble(g, speech);
            }
            lastDrawnSpeech = speech;
            bool ok = frame.PresentRegion(Handle, left, top, region);
            renders++;
            if (renders <= 3 || (!ok && renders % 100 == 0))
                Log.W("render #" + renders + " ok=" + ok + " pos=" + left + "," + top + " size=" + W + "x" + H);
        }

        static Color C(string hex) { return ColorTranslator.FromHtml(hex); }

        // ---- cachés para no recalcular lo mismo en cada fotograma ----
        static readonly Font BUBBLE_FONT = new Font("Segoe UI", 15f, FontStyle.Bold, GraphicsUnit.Pixel);
        static readonly Font[] ZZZ_FONTS = MakeZzzFonts();
        static Font[] MakeZzzFonts()
        {
            Font[] f = new Font[11];
            for (int i = 0; i <= 10; i++) f[i] = new Font("Segoe UI", 12f + i, FontStyle.Bold, GraphicsUnit.Pixel);
            return f;
        }
        Bitmap bodyCache; bool bodyCacheHot; float bodyCacheS;
        Bitmap bubbleCache; string bubbleKey; RectangleF bubbleRect;

        string SpriteFrame()
        {
            switch (state)
            {
                case PetState.Walk:
                case PetState.Climb:
                    return Math.Sin(walkPhase) > 0 ? "walk1" : "walk2";
                case PetState.Trench:
                    return lean > 3f || lean < -2f ? (Math.Sin(t * 11f) > 0 ? "walk1" : "walk2") : "idle";
                case PetState.Sleep: return "sleep";
                case PetState.Drag: return "fall";
                case PetState.Fall: return chute ? "idle" : "fall";
                case PetState.Dance:
                case PetState.MusicDance:
                case PetState.Confetti: return "dance";
                case PetState.Crazy: return "crazy";
            }
            return "idle";
        }

        // giro de la imagen para apuntar (y para dar vueltas en el modo loco)
        float SpriteAimRot()
        {
            if (state == PetState.Crazy) return (crazyAngle * 0.6f) % 360f;
            if (hasAim && (state == PetState.Shoot || state == PetState.Guard || state == PetState.Dodge))
                return Math.Max(-28f, Math.Min(28f, AimAngle() * 0.6f));
            if (state == PetState.Shoot || state == PetState.Trench) return -recoil * 3f;
            return 0;
        }

        void DrawPetSprite(Graphics g)
        {
            float bob = state == PetState.Squats ? 0 : BodyBob();
            DrawGroundShadow(g);
            if (chute) DrawChute(g, bob);
            string fn = SpriteFrame();
            Bitmap bm = sprites.Get(fn);
            GraphicsState st = g.Save();
            float rot = SpriteAimRot();
            if (rot != 0)
            {
                g.TranslateTransform(0, -70 + bob);
                g.RotateTransform(rot);
                g.TranslateTransform(0, 70 - bob);
            }
            if (state == PetState.Squats)
            {
                float k = (1f - (float)Math.Cos(squatPhase)) * 0.5f;
                g.ScaleTransform(1f + 0.07f * k, 1f - 0.14f * k);
            }
            float w = bm.Width / 2f, h = bm.Height / 2f;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(bm, new RectangleF(-w / 2 - recoil * 3f, -h + bob, w, h));
            if (flashLeft > 0 && fn != "crazy")
            {
                PointF mz = SpriteSet.Muzzle(fn);
                DrawFlash(g, mz.X + 8 - recoil * 3f, mz.Y + bob, 0.9f);
            }
            else if (flashLeft > 0)
            {
                PointF mz = SpriteSet.Muzzle(fn);
                DrawFlash(g, mz.X + 14, mz.Y + bob, 0.7f);
            }
            g.Restore(st);
            if (state == PetState.Squats && squatReps > 2)
                using (SolidBrush sweat = new SolidBrush(Color.FromArgb(200, 120, 190, 255)))
                    g.FillEllipse(sweat, -30, -130 + (t * 20f % 10f), 5, 8);
        }

        // Cuerpo con sombras y textura: se dibuja una vez y se guarda como imagen
        void DrawBodyTo(Graphics g, float bob, bool hot)
        {
            Color ink = C("#3B2414");
            // cuerpo de cacahuete
            RectangleF upper = new RectangleF(-35, -134 + bob, 70, 68);
            RectangleF lower = new RectangleF(-31, -80 + bob, 62, 62);
            using (Pen outline = new Pen(Color.FromArgb(235, 62, 36, 16), 4.5f))
            {
                g.DrawEllipse(outline, upper);
                g.DrawEllipse(outline, lower);
            }
            using (GraphicsPath body = new GraphicsPath(FillMode.Winding))
            {
                body.AddEllipse(upper); body.AddEllipse(lower);
                
                Color top = hot ? C("#F2B48C") : C("#E8C28C");
                Color bottom = hot ? C("#B86A44") : C("#A8733F");
                using (LinearGradientBrush lg = new LinearGradientBrush(new RectangleF(-36, -136 + bob, 72, 122), top, bottom, 70f))
                    g.FillPath(lg, body);

                GraphicsState cs = g.Save();
                g.SetClip(body);

                // volumen de cada lobulo: luz arriba a la izquierda, sombra en el borde
                LobeShade(g, upper, 0.36f, 0.30f);
                LobeShade(g, lower, 0.38f, 0.28f);

                // cintura: pliegue con sombra
                using (GraphicsPath wp = new GraphicsPath())
                {
                    wp.AddEllipse(-30, -80 + bob, 60, 16);
                    using (PathGradientBrush wb = new PathGradientBrush(wp))
                    {
                        wb.CenterColor = Color.FromArgb(120, 95, 55, 22);
                        wb.SurroundColors = new Color[] { Color.FromArgb(0, 95, 55, 22) };
                        g.FillPath(wb, wp);
                    }
                }
                using (Pen crease = new Pen(Color.FromArgb(110, 90, 50, 20), 1.8f))
                    g.DrawArc(crease, -26, -78 + bob, 52, 12, 20, 140);

                // textura de cascara: red de nervios y hoyuelos en relieve
                using (Pen vein = new Pen(Color.FromArgb(55, 110, 65, 25), 1.4f))
                using (Pen veinHi = new Pen(Color.FromArgb(45, 255, 240, 210), 1f))
                {
                    for (int i = 0; i < SHELL_VEINS.Length; i++)
                    {
                        float vx0 = SHELL_VEINS[i];
                        g.DrawBezier(vein, vx0, -134 + bob, vx0 * 1.25f, -105 + bob, vx0 * 0.8f, -80 + bob, vx0 * 1.15f, -20 + bob);
                        g.DrawBezier(veinHi, vx0 + 1.2f, -134 + bob, vx0 * 1.25f + 1.2f, -105 + bob, vx0 * 0.8f + 1.2f, -80 + bob, vx0 * 1.15f + 1.2f, -20 + bob);
                    }
                }
                using (SolidBrush pit = new SolidBrush(Color.FromArgb(70, 105, 60, 22)))
                using (SolidBrush pitHi = new SolidBrush(Color.FromArgb(60, 255, 244, 220)))
                {
                    for (int i = 0; i < SHELL_PITS.Length; i += 3)
                    {
                        float x = SHELL_PITS[i], y = SHELL_PITS[i + 1] + bob, r = SHELL_PITS[i + 2];
                        g.FillEllipse(pitHi, x - r * 0.5f + 0.8f, y - r * 0.35f + 1f, r, r * 0.7f);
                        g.FillEllipse(pit, x - r * 0.5f, y - r * 0.35f, r, r * 0.7f);
                    }
                }

                // brillo especular suave
                using (GraphicsPath sp = new GraphicsPath())
                {
                    sp.AddEllipse(-27, -129 + bob, 22, 30);
                    using (PathGradientBrush sb2 = new PathGradientBrush(sp))
                    {
                        sb2.CenterPoint = new PointF(-17, -118 + bob);
                        sb2.CenterColor = Color.FromArgb(140, 255, 252, 240);
                        sb2.SurroundColors = new Color[] { Color.FromArgb(0, 255, 252, 240) };
                        g.FillPath(sb2, sp);
                    }
                }
                // luz de rebote abajo a la derecha
                using (Pen rim = new Pen(Color.FromArgb(70, 255, 220, 170), 3f))
                {
                    g.DrawArc(rim, lower.X + 3, lower.Y + 3, lower.Width - 6, lower.Height - 6, 10, 70);
                    g.DrawArc(rim, upper.X + 3, upper.Y + 3, upper.Width - 6, upper.Height - 6, 15, 50);
                }

                // bandana con tela: degradado, sombra que proyecta y pliegues
                using (SolidBrush cast = new SolidBrush(Color.FromArgb(70, 70, 35, 10)))
                    g.FillRectangle(cast, -40, -113 + bob, 80, 4);
                using (LinearGradientBrush cloth = new LinearGradientBrush(new RectangleF(-40, -125 + bob, 80, 13), C("#E53935"), C("#8E1616"), 90f))
                {
                    ColorBlend cb = new ColorBlend(3);
                    cb.Colors = new Color[] { C("#EF5350"), C("#D32F2F"), C("#8E1616") };
                    cb.Positions = new float[] { 0f, 0.45f, 1f };
                    cloth.InterpolationColors = cb;
                    g.FillRectangle(cloth, -40, -124 + bob, 80, 11);
                }
                using (Pen fold = new Pen(Color.FromArgb(90, 90, 10, 10), 1.1f))
                {
                    g.DrawLine(fold, -20, -123 + bob, -14, -114 + bob);
                    g.DrawLine(fold, 4, -123 + bob, 9, -114 + bob);
                    g.DrawLine(fold, 24, -123 + bob, 28, -114 + bob);
                }
                using (Pen shine = new Pen(Color.FromArgb(90, 255, 200, 200), 1.2f))
                    g.DrawLine(shine, -40, -122.5f + bob, 40, -122.5f + bob);
                g.Restore(cs);
            }
            using (GraphicsPath kp = new GraphicsPath())
            {
                kp.AddEllipse(-35, -122 + bob, 10, 10);
                using (PathGradientBrush kb = new PathGradientBrush(kp))
                {
                    kb.CenterPoint = new PointF(-31.5f, -119 + bob);
                    kb.CenterColor = C("#E35050");
                    kb.SurroundColors = new Color[] { C("#7F1414") };
                    g.FillPath(kb, kp);
                }
                using (Pen o = new Pen(Color.FromArgb(200, 60, 15, 10), 1.4f)) g.DrawPath(o, kp);
            }

        }

        void DrawBodyCached(Graphics g, float bob)
        {
            bool hot = state == PetState.Crazy;
            if (bodyCache == null || bodyCacheHot != hot || bodyCacheS != S)
            {
                if (bodyCache != null) bodyCache.Dispose();
                int bw = (int)Math.Ceiling(88 * S), bh = (int)Math.Ceiling(132 * S);
                bodyCache = new Bitmap(bw, bh, PixelFormat.Format32bppPArgb);
                using (Graphics cg = Graphics.FromImage(bodyCache))
                {
                    cg.SmoothingMode = SmoothingMode.AntiAlias;
                    cg.ScaleTransform(S, S);
                    cg.TranslateTransform(44, 139);
                    DrawBodyTo(cg, 0, hot);
                }
                bodyCacheHot = hot; bodyCacheS = S;
            }
            g.InterpolationMode = InterpolationMode.HighQualityBilinear;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(bodyCache, new RectangleF(-44, -139 + bob, 88, 132));
            g.PixelOffsetMode = PixelOffsetMode.Default;
        }

        void DrawPet(Graphics g)
        {
            if (sprites != null) { DrawPetSprite(g); return; }
            float bob = BodyBob();
            bool inAir = state == PetState.Drag || state == PetState.Fall || state == PetState.Crazy ||
                         (state == PetState.Dance && py < Ground() - 1);
            Color ink = C("#3B2414");

            DrawGroundShadow(g);
            if (chute) DrawChute(g, bob);

            // cintas de la bandana (detras)
            float fl = (float)Math.Sin(t * (state == PetState.Walk || chute ? 14f : 7f)) * 3.5f;
            using (SolidBrush red = new SolidBrush(C("#C62828")))
            using (Pen o = new Pen(ink, 2f))
            {
                PointF[] t1 = { new PointF(-30, -121 + bob), new PointF(-52, -128 + fl + bob), new PointF(-57, -119 + fl + bob), new PointF(-31, -113 + bob) };
                PointF[] t2 = { new PointF(-31, -116 + bob), new PointF(-50, -106 - fl + bob), new PointF(-45, -99 - fl + bob), new PointF(-29, -111 + bob) };
                g.FillPolygon(red, t2); g.DrawPolygon(o, t2);
                g.FillPolygon(red, t1); g.DrawPolygon(o, t1);
            }

            // piernas y zapatos
            float swing = 0;
            if (state == PetState.Walk || state == PetState.Climb) swing = (float)Math.Sin(walkPhase) * 8f;
            if (inAir) swing = (float)Math.Sin(t * 13f) * 7f;
            if (state == PetState.MusicDance) swing = (float)Math.Sin(t * 8f) * 6f;
            float footY = inAir ? -2f : -6f;
            float squatSpread = state == PetState.Squats ? bob * 0.5f : 0f;
            using (Pen leg = new Pen(ink, 4.5f))
            {
                leg.StartCap = LineCap.Round; leg.EndCap = LineCap.Round;
                g.DrawLine(leg, -11, -22 + bob, -11 + swing - squatSpread, footY);
                g.DrawLine(leg, 11, -22 + bob, 11 - swing + squatSpread, footY);
            }
            DrawShoe(g, -11 + swing - squatSpread, footY);
            DrawShoe(g, 11 - swing + squatSpread, footY);

            // manos a partir del arma
            PointF[] hands;
            if (weapon == Weapon.Bazooka) hands = new PointF[] { new PointF(-2, 12), new PointF(30, 12) };
            else if (weapon == Weapon.Confetti) hands = new PointF[] { new PointF(-3, 6), new PointF(30, -1) };
            else hands = new PointF[] { new PointF(-3, 5), new PointF(37, -4) };
            using (Matrix gm = GunMatrix()) gm.TransformPoints(hands);

            using (Pen arm = new Pen(ink, 4f))
            {
                arm.StartCap = LineCap.Round; arm.EndCap = LineCap.Round;
                g.DrawLine(arm, -18, -74 + bob, hands[0].X, hands[0].Y);
            }

            // cuerpo de cacahuete (desde la cache)
            DrawBodyCached(g, bob);

            DrawFace(g, bob);
            DrawWeapon(g);

            using (Pen arm = new Pen(ink, 4f))
            {
                arm.StartCap = LineCap.Round; arm.EndCap = LineCap.Round;
                g.DrawLine(arm, 20, -76 + bob, hands[1].X, hands[1].Y);
            }
            DrawGlove(g, hands[0]);
            DrawGlove(g, hands[1]);

            if (state == PetState.Throw && shotsLeft > 0) DrawPipa(g, hands[1].X + 4, hands[1].Y - 8, 30f + stateTime * 400f, 1f);
        }

        static readonly float[] SHELL_VEINS = { -24f, -12f, 0f, 12f, 23f };
        static readonly float[] SHELL_PITS = MakePits();
        static float[] MakePits()
        {
            Random r = new Random(7);
            List<float> l = new List<float>();
            for (int i = 0; i < 70; i++)
            {
                float x = -32 + (float)r.NextDouble() * 64;
                float y = -130 + (float)r.NextDouble() * 108;
                l.Add(x); l.Add(y); l.Add(2.4f + (float)r.NextDouble() * 2.6f);
            }
            return l.ToArray();
        }

        static void LobeShade(Graphics g, RectangleF lobe, float lx, float ly)
        {
            using (GraphicsPath p = new GraphicsPath())
            {
                p.AddEllipse(lobe);
                using (PathGradientBrush light = new PathGradientBrush(p))
                {
                    light.CenterPoint = new PointF(lobe.X + lobe.Width * lx, lobe.Y + lobe.Height * ly);
                    light.CenterColor = Color.FromArgb(120, 255, 240, 205);
                    light.SurroundColors = new Color[] { Color.FromArgb(0, 255, 240, 205) };
                    g.FillPath(light, p);
                }
                using (PathGradientBrush dark = new PathGradientBrush(p))
                {
                    dark.CenterPoint = new PointF(lobe.X + lobe.Width * 0.45f, lobe.Y + lobe.Height * 0.42f);
                    dark.CenterColor = Color.FromArgb(0, 80, 45, 15);
                    dark.SurroundColors = new Color[] { Color.FromArgb(130, 80, 45, 15) };
                    dark.FocusScales = new PointF(0.62f, 0.62f);
                    g.FillPath(dark, p);
                }
            }
        }

        // sombra en el suelo (se hace mas pequena y clara cuanto mas alto esta)
        void DrawGroundShadow(Graphics g)
        {
            if (orient != Orient.Floor || state == PetState.Climb) return;
            float height = Math.Max(0, (Ground() - py) / S);
            if (height > 180) return;
            float k = 1f - height / 180f;
            float w = (64 + 10 * squash) * (0.5f + 0.5f * k), h = 11 * (0.5f + 0.5f * k);
            using (GraphicsPath p = new GraphicsPath())
            {
                p.AddEllipse(-w / 2, height - h / 2 - 1, w, h);
                using (PathGradientBrush b = new PathGradientBrush(p))
                {
                    b.CenterColor = Color.FromArgb((int)(110 * k), 0, 0, 0);
                    b.SurroundColors = new Color[] { Color.FromArgb(0, 0, 0, 0) };
                    g.FillPath(b, p);
                }
            }
        }

        void DrawChute(Graphics g, float bob)
        {
            Color ink = C("#3B2414");
            RectangleF canopy = new RectangleF(-92, -290 + bob, 184, 116);
            using (SolidBrush red = new SolidBrush(C("#E53935")))
            using (SolidBrush white = new SolidBrush(Color.FromArgb(245, 245, 245)))
            {
                for (int i = 0; i < 4; i++) g.FillPie(i % 2 == 0 ? red : white, canopy.X, canopy.Y, canopy.Width, canopy.Height, 180 + i * 45, 45);
            }
            using (Pen o = new Pen(ink, 2.5f))
            {
                g.DrawArc(o, canopy.X, canopy.Y, canopy.Width, canopy.Height, 180, 180);
                g.DrawLine(o, canopy.Left, canopy.Top + canopy.Height / 2, canopy.Right, canopy.Top + canopy.Height / 2);
            }
            using (Pen s = new Pen(Color.FromArgb(160, 60, 40, 20), 1.2f))
            {
                float cy = canopy.Top + canopy.Height / 2;
                g.DrawLine(s, -92, cy, -16, -126 + bob);
                g.DrawLine(s, -40, cy, -10, -128 + bob);
                g.DrawLine(s, 40, cy, 10, -128 + bob);
                g.DrawLine(s, 92, cy, 16, -126 + bob);
            }
        }

        void DrawShoe(Graphics g, float x, float y)
        {
            using (LinearGradientBrush b = new LinearGradientBrush(new RectangleF(x - 7, y - 7, 19, 12), C("#4A4A4E"), C("#141416"), 90f))
                g.FillEllipse(b, x - 7, y - 6, 19, 10);
            using (SolidBrush sole = new SolidBrush(C("#0D0D0E")))
                g.FillRectangle(sole, x - 5, y + 2, 15, 1.6f);
            using (SolidBrush hl = new SolidBrush(Color.FromArgb(130, 255, 255, 255)))
                g.FillEllipse(hl, x + 2, y - 4.8f, 5, 2.2f);
        }

        void DrawGlove(Graphics g, PointF p)
        {
            using (GraphicsPath gp = new GraphicsPath())
            {
                gp.AddEllipse(p.X - 6.5f, p.Y - 6.5f, 13, 13);
                using (PathGradientBrush b = new PathGradientBrush(gp))
                {
                    b.CenterPoint = new PointF(p.X - 2f, p.Y - 2.5f);
                    b.CenterColor = Color.White;
                    b.SurroundColors = new Color[] { C("#C9C4BC") };
                    g.FillPath(b, gp);
                }
                using (Pen o = new Pen(Color.FromArgb(220, 59, 36, 20), 1.6f)) g.DrawPath(o, gp);
                using (Pen knuckle = new Pen(Color.FromArgb(90, 120, 110, 100), 0.9f))
                {
                    g.DrawArc(knuckle, p.X - 4, p.Y - 1, 4, 4, 180, 180);
                    g.DrawArc(knuckle, p.X, p.Y - 1, 4, 4, 180, 180);
                }
            }
        }

        void DrawPipa(Graphics g, float x, float y, float rot, float scale)
        {
            GraphicsState st = g.Save();
            g.TranslateTransform(x, y);
            g.RotateTransform(rot);
            g.ScaleTransform(scale, scale);
            using (GraphicsPath p = new GraphicsPath())
            {
                p.AddBezier(-9, 0, -6, -6, 6, -5, 10, 0);
                p.AddBezier(10, 0, 6, 5, -6, 6, -9, 0);
                using (SolidBrush b = new SolidBrush(C("#1E1E1E"))) g.FillPath(b, p);
                using (Pen w = new Pen(Color.FromArgb(230, 240, 240, 240), 1.3f))
                {
                    g.DrawLine(w, -5, -2.5f, 6, -2f);
                    g.DrawLine(w, -5, 2.5f, 6, 2f);
                }
            }
            g.Restore(st);
        }

        void DrawFace(Graphics g, float bob)
        {
            Color ink = C("#2B1A0E");
            bool crazy = state == PetState.Crazy;
            bool sleeping = state == PetState.Sleep;
            bool closed = sleeping || blinkLeft > 0 || state == PetState.Squats && squatPhase > 2.4f && squatPhase < 3.9f;
            bool surprised = state == PetState.Drag || (state == PetState.Fall && !chute);
            bool happy = state == PetState.MusicDance || state == PetState.Dance || state == PetState.Confetti || chute;
            bool shouting = crazy || state == PetState.Shoot || state == PetState.Bazooka || state == PetState.Throw ||
                            state == PetState.Reload || (angry && speechLeft > 0);
            bool mad = shouting || angry || anger > 1f || state == PetState.Guard || state == PetState.Dodge;

            float ey = -99 + bob;
            float[] ex = { 3, 21 };

            using (Pen p = new Pen(ink, 2.4f))
            using (SolidBrush white = new SolidBrush(Color.White))
            using (SolidBrush pupil = new SolidBrush(ink))
            {
                p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
                for (int i = 0; i < 2; i++)
                {
                    if (closed)
                    {
                        g.DrawArc(p, ex[i] - 6, ey - 3, 12, 8, 10, 160);
                        continue;
                    }
                    float ew = (surprised || crazy) ? 16 : 13, eh = (surprised || crazy) ? 19 : 16;
                    g.FillEllipse(white, ex[i] - ew / 2, ey - eh / 2, ew, eh);
                    using (SolidBrush lid = new SolidBrush(Color.FromArgb(55, 120, 90, 70)))
                        g.FillPie(lid, ex[i] - ew / 2, ey - eh / 2, ew, eh, 180, 180);
                    g.DrawEllipse(p, ex[i] - ew / 2, ey - eh / 2, ew, eh);
                    float ps = crazy ? 3f : (surprised ? 4.5f : 6f);
                    float look = surprised ? 0 : 2f;
                    float jx = 0, jy = 0;
                    if (crazy)
                    {
                        look = 0; jx = Rand(-3f, 3f); jy = Rand(-3f, 3f);
                        using (Pen vein = new Pen(Color.FromArgb(150, 220, 40, 40), 1f))
                        {
                            g.DrawLine(vein, ex[i] - 7, ey - 2, ex[i] - 3, ey);
                            g.DrawLine(vein, ex[i] + 7, ey + 3, ex[i] + 3, ey + 1);
                        }
                    }
                    float ir = ps + 3.2f;
                    using (SolidBrush iris = new SolidBrush(C("#6B4423")))
                        g.FillEllipse(iris, ex[i] - ir / 2 + look + jx, ey - ir / 2 + 1 + jy, ir, ir + 1);
                    g.FillEllipse(pupil, ex[i] - ps / 2 + look + jx, ey - ps / 2 + 1 + jy, ps, ps + 1);
                    using (SolidBrush glint = new SolidBrush(Color.White))
                        g.FillEllipse(glint, ex[i] + look + jx - 0.5f, ey - 1.5f + jy, 2, 2);
                }

                using (Pen brow = new Pen(ink, 3.6f))
                {
                    brow.StartCap = LineCap.Round; brow.EndCap = LineCap.Round;
                    if (mad)
                    {
                        g.DrawLine(brow, -5, -115 + bob, 9, -108 + bob);
                        g.DrawLine(brow, 15, -108 + bob, 29, -115 + bob);
                    }
                    else if (surprised)
                    {
                        g.DrawArc(brow, -4, -120 + bob, 14, 6, 200, 140);
                        g.DrawArc(brow, 14, -120 + bob, 14, 6, 200, 140);
                    }
                    else
                    {
                        g.DrawLine(brow, -4, -111 + bob, 9, -112 + bob);
                        g.DrawLine(brow, 15, -112 + bob, 28, -110 + bob);
                    }
                }

                if (shouting)
                {
                    using (SolidBrush m = new SolidBrush(C("#5A1010"))) g.FillEllipse(m, 5, -91 + bob, 17, 13);
                    using (SolidBrush teeth = new SolidBrush(Color.White)) g.FillRectangle(teeth, 8, -90 + bob, 11, 3);
                    g.DrawEllipse(p, 5, -91 + bob, 17, 13);
                }
                else if (surprised)
                {
                    using (SolidBrush m = new SolidBrush(C("#5A1010"))) g.FillEllipse(m, 9, -89 + bob, 9, 11);
                    g.DrawEllipse(p, 9, -89 + bob, 9, 11);
                }
                else if (sleeping)
                {
                    g.DrawEllipse(p, 11, -86 + bob, 5, 4);
                }
                else if (happy)
                {
                    using (SolidBrush m = new SolidBrush(C("#5A1010"))) g.FillPie(m, 5, -97 + bob, 18, 14, 0, 180);
                    g.DrawArc(p, 5, -97 + bob, 18, 14, 0, 180);
                    g.DrawLine(p, 5, -90 + bob, 23, -90 + bob);
                }
                else if (state == PetState.Squats)
                {
                    g.DrawLine(p, 7, -87 + bob, 21, -87 + bob);
                }
                else
                {
                    g.DrawArc(p, 5, -94 + bob, 18, 10, 20, 140);
                    g.DrawLine(p, 21, -88 + bob, 24, -90 + bob);
                }
            }
            using (SolidBrush blush = new SolidBrush(Color.FromArgb(state == PetState.Squats ? 140 : 70, 230, 90, 90)))
                g.FillEllipse(blush, 25, -92 + bob, 8, 5);
            if (state == PetState.Squats && squatReps > 2)
                using (SolidBrush sweat = new SolidBrush(Color.FromArgb(200, 120, 190, 255)))
                    g.FillEllipse(sweat, -30, -112 + bob + (t * 20f % 10f), 5, 8);
        }

        void DrawWeapon(Graphics g)
        {
            GraphicsState st = g.Save();
            using (Matrix m = GunMatrix()) g.MultiplyTransform(m);
            if (weapon == Weapon.Bazooka) DrawBazooka(g);
            else if (weapon == Weapon.Confetti) DrawConfettiGun(g);
            else DrawAK(g, !(state == PetState.Reload && stateTime < 0.9f));
            g.Restore(st);
        }

        void DrawFlash(Graphics g, float cx, float cy, float big)
        {
            if (flashLeft <= 0) return;
            PointF[] star = new PointF[16];
            for (int i = 0; i < 16; i++)
            {
                double a = i * Math.PI / 8;
                float r = ((i % 2 == 0) ? Rand(13f, 21f) : 6f) * big;
                star[i] = new PointF(cx + (float)Math.Cos(a) * r * 1.3f, cy + (float)Math.Sin(a) * r * 0.8f);
            }
            using (SolidBrush f1 = new SolidBrush(C("#FF8F1F"))) g.FillPolygon(f1, star);
            using (SolidBrush f2 = new SolidBrush(C("#FFE65C"))) g.FillEllipse(f2, cx - 8 * big, cy - 5 * big, 16 * big, 10 * big);
        }

        void DrawAK(Graphics g, bool showMag)
        {
            Color woodDark = C("#4E260E"), metalHi = C("#8A8E98");
            using (Pen o = new Pen(Color.FromArgb(230, 20, 14, 8), 1.2f))
            using (LinearGradientBrush bWood = GunBrush(new Color[] { C("#B8693A"), C("#8E4A1E"), C("#5A2C10") }, -15, 14))
            using (LinearGradientBrush bMetal = GunBrush(new Color[] { C("#5C6069"), C("#2A2C31"), C("#3A3D44"), C("#16171A") }, -14, 14))
            using (SolidBrush bMetalHi = new SolidBrush(Color.FromArgb(170, metalHi)))
            using (LinearGradientBrush bMag = GunBrush(new Color[] { C("#E0823A"), C("#C4621C"), C("#7A3A0E") }, 0, 27))
            {
                o.LineJoin = LineJoin.Round;
                PointF[] stock = { new PointF(-48, -5), new PointF(-14, -8), new PointF(-14, 2), new PointF(-45, 12), new PointF(-50, 10) };
                g.FillPolygon(bWood, stock); g.DrawPolygon(o, stock);
                using (Pen grain = new Pen(Color.FromArgb(120, woodDark), 0.8f))
                {
                    g.DrawLine(grain, -44, 0, -18, -3);
                    g.DrawBezier(grain, -46, 5, -38, 3, -28, 5, -16, -1);
                    g.DrawLine(grain, 30, -5, 47, -6);
                }
                PointF[] grip = { new PointF(-7, 0), new PointF(3, 0), new PointF(1, 14), new PointF(-9, 13) };
                g.FillPolygon(bMetal, grip); g.DrawPolygon(o, grip);
                g.DrawArc(o, 2, -2, 9, 9, 0, 180);
                if (showMag)
                {
                    PointF[] magz = { new PointF(10, 1), new PointF(20, 1), new PointF(25, 10), new PointF(29, 23), new PointF(20, 26), new PointF(16, 13) };
                    g.FillPolygon(bMag, magz); g.DrawPolygon(o, magz);
                    using (Pen rib = new Pen(Color.FromArgb(120, 90, 40, 10), 1f))
                    {
                        g.DrawLine(rib, 14, 6, 22, 5);
                        g.DrawLine(rib, 17, 13, 25, 12);
                        g.DrawLine(rib, 19, 20, 27, 19);
                    }
                }
                g.FillRectangle(bMetal, -15, -10, 43, 11); g.DrawRectangle(o, -15, -10, 43, 11);
                g.FillRectangle(bMetalHi, -12, -8, 30, 2.5f);
                g.FillRectangle(bMetal, 22, -13, 5, 3);
                g.FillRectangle(bWood, 28, -9, 21, 9); g.DrawRectangle(o, 28, -9, 21, 9);
                g.FillRectangle(bWood, 28, -14, 25, 4); g.DrawRectangle(o, 28, -14, 25, 4);
                g.FillRectangle(bMetal, 49, -7, 31, 4); g.DrawRectangle(o, 49, -7, 31, 4);
                g.FillRectangle(bMetal, 73, -13, 3, 6);
                g.FillRectangle(bMetal, 80, -8, 7, 6); g.DrawRectangle(o, 80, -8, 7, 6);
            }
            using (Pen glint = new Pen(Color.FromArgb(150, 220, 225, 235), 0.9f))
            {
                g.DrawLine(glint, 50, -6.4f, 79, -6.4f);
                g.DrawLine(glint, -14, -9.2f, 27, -9.2f);
            }
            DrawFlash(g, 96, -5, 1f);
        }

        static LinearGradientBrush GunBrush(Color[] cols, float y0, float y1)
        {
            LinearGradientBrush b = new LinearGradientBrush(new PointF(0, y0), new PointF(0, y1), cols[0], cols[cols.Length - 1]);
            ColorBlend cb = new ColorBlend(cols.Length);
            cb.Colors = cols;
            float[] pos = new float[cols.Length];
            for (int i = 0; i < cols.Length; i++) pos[i] = (float)i / (cols.Length - 1);
            cb.Positions = pos;
            b.InterpolationColors = cb;
            return b;
        }

        void DrawBazooka(Graphics g)
        {
            using (Pen o = new Pen(C("#1A1209"), 1.6f))
            using (SolidBrush olive = new SolidBrush(C("#556B2F")))
            using (SolidBrush oliveDark = new SolidBrush(C("#3B4A20")))
            using (SolidBrush metal = new SolidBrush(C("#2E2F35")))
            using (SolidBrush jar = new SolidBrush(C("#C68642")))
            using (SolidBrush lid = new SolidBrush(C("#D32F2F")))
            {
                o.LineJoin = LineJoin.Round;
                PointF[] flare = { new PointF(-52, -16), new PointF(-42, -12), new PointF(-42, 5), new PointF(-52, 9) };
                g.FillPolygon(oliveDark, flare); g.DrawPolygon(o, flare);
                g.FillRectangle(olive, -42, -12, 120, 17); g.DrawRectangle(o, -42, -12, 120, 17);
                g.FillRectangle(oliveDark, -28, -12, 5, 17);
                g.FillRectangle(oliveDark, 22, -12, 5, 17);
                g.FillRectangle(oliveDark, 58, -12, 5, 17);
                g.FillRectangle(metal, 76, -14, 7, 21); g.DrawRectangle(o, 76, -14, 7, 21);
                g.FillRectangle(metal, 40, -18, 3, 6);
                g.FillRectangle(metal, -6, 5, 8, 13); g.DrawRectangle(o, -6, 5, 8, 13);
                g.FillRectangle(metal, 26, 5, 8, 11); g.DrawRectangle(o, 26, 5, 8, 11);
                // tarro de mantequilla pintado en el tubo
                g.FillEllipse(jar, 0, -10, 14, 13); g.DrawEllipse(o, 0, -10, 14, 13);
                g.FillRectangle(lid, 1, -11, 12, 4);
            }
            DrawFlash(g, 92, -4, 1.5f);
        }

        void DrawConfettiGun(Graphics g)
        {
            using (Pen o = new Pen(C("#1A1209"), 1.6f))
            using (SolidBrush tank = new SolidBrush(C("#FFC107")))
            using (SolidBrush pink = new SolidBrush(C("#EC407A")))
            using (SolidBrush blue = new SolidBrush(C("#29B6F6")))
            using (SolidBrush metal = new SolidBrush(C("#2E2F35")))
            {
                o.LineJoin = LineJoin.Round;
                g.FillEllipse(tank, -40, -15, 28, 22); g.DrawEllipse(o, -40, -15, 28, 22);
                g.FillRectangle(pink, -14, -10, 52, 12); g.DrawRectangle(o, -14, -10, 52, 12);
                Color[] cs = { C("#4CAF50"), C("#FFEB3B"), C("#2196F3"), C("#9C27B0") };
                for (int i = 0; i < 4; i++) using (SolidBrush b = new SolidBrush(cs[i])) g.FillRectangle(b, -8 + i * 11, -8, 5, 8);
                PointF[] noz = { new PointF(38, -11), new PointF(70, -15), new PointF(70, 5), new PointF(38, 1) };
                g.FillPolygon(blue, noz); g.DrawPolygon(o, noz);
                PointF[] grip = { new PointF(-7, 2), new PointF(2, 2), new PointF(0, 14), new PointF(-9, 13) };
                g.FillPolygon(metal, grip); g.DrawPolygon(o, grip);
            }
        }

        void DrawZzz(Graphics g)
        {
            for (int i = 0; i < 3; i++)
            {
                float ph = (t * 0.6f + i * 0.33f) % 1f;
                float x = AX + 15 + ph * 30;
                float y = orient == Orient.Ceiling ? AY + 70 + ph * 45 : AY - 70 - ph * 45;
                using (SolidBrush b2 = new SolidBrush(Color.FromArgb((int)(220 * (1 - ph)), 60, 60, 90)))
                    g.DrawString("z", ZZZ_FONTS[(int)Math.Min(10, ph * 10f)], b2, x, y);
            }
        }

        // Bocadillo: se dibuja una vez por frase y se reutiliza
        RectangleF BubbleLayout(string text, out float x, out float y, out float w, out float h, out float baseY, out float tipY, out SizeF sz)
        {
            using (Bitmap tmp = new Bitmap(1, 1))
            using (Graphics mg = Graphics.FromImage(tmp)) sz = mg.MeasureString(text, BUBBLE_FONT, 280);
            w = sz.Width + 22; h = sz.Height + 12;
            bool below = orient == Orient.Ceiling;
            x = Math.Max(4, Math.Min(LW - w - 4, AX - w / 2));
            if (below) { y = AY + 92; baseY = y + 1; tipY = y - 12; return new RectangleF(x - 2, tipY - 2, w + 4, h + 16); }
            float topOfPet = AY - (chute ? 235 : 82);
            y = Math.Max(4, topOfPet - h - 14);
            baseY = y + h - 1; tipY = y + h + 12;
            return new RectangleF(x - 2, y - 2, w + 4, h + 16);
        }

        string BubbleKeyFor(string text) { return text + "|" + (orient == Orient.Ceiling) + "|" + chute + "|" + S; }

        RectangleF BubbleBounds(string text)
        {
            if (bubbleKey == BubbleKeyFor(text)) return bubbleRect;
            float x, y, w, h, b, tp; SizeF sz;
            return BubbleLayout(text, out x, out y, out w, out h, out b, out tp, out sz);
        }

        void DrawBubble(Graphics g, string text)
        {
            string key = BubbleKeyFor(text);
            if (bubbleKey != key || bubbleCache == null)
            {
                if (bubbleCache != null) bubbleCache.Dispose();
                float x, y, w, h, baseY, tipY; SizeF sz;
                bubbleRect = BubbleLayout(text, out x, out y, out w, out h, out baseY, out tipY, out sz);
                bubbleCache = new Bitmap((int)Math.Ceiling(bubbleRect.Width * S) + 2, (int)Math.Ceiling(bubbleRect.Height * S) + 2, PixelFormat.Format32bppPArgb);
                using (Graphics cg = Graphics.FromImage(bubbleCache))
                {
                    cg.SmoothingMode = SmoothingMode.AntiAlias;
                    cg.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
                    cg.ScaleTransform(S, S);
                    cg.TranslateTransform(-bubbleRect.X, -bubbleRect.Y);
                    PaintBubble(cg, text, x, y, w, h, baseY, tipY, sz);
                }
                bubbleKey = key;
            }
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(bubbleCache, new RectangleF(bubbleRect.X, bubbleRect.Y, bubbleCache.Width / S, bubbleCache.Height / S));
            g.PixelOffsetMode = PixelOffsetMode.Default;
        }

        void PaintBubble(Graphics g, string text, float x, float y, float w, float h, float baseY, float tipY, SizeF sz)
        {
            Font f = BUBBLE_FONT;
            {
                float tx = AX;
                using (GraphicsPath p = new GraphicsPath())
                {
                    float r = 10;
                    p.AddArc(x, y, r * 2, r * 2, 180, 90);
                    p.AddArc(x + w - r * 2, y, r * 2, r * 2, 270, 90);
                    p.AddArc(x + w - r * 2, y + h - r * 2, r * 2, r * 2, 0, 90);
                    p.AddArc(x, y + h - r * 2, r * 2, r * 2, 90, 90);
                    p.CloseFigure();
                    PointF[] tail = { new PointF(tx - 8, baseY), new PointF(tx + 8, baseY), new PointF(tx, tipY) };
                    using (SolidBrush wb = new SolidBrush(Color.White))
                    using (Pen o = new Pen(Color.FromArgb(40, 30, 20), 2.2f))
                    {
                        g.FillPolygon(wb, tail);
                        g.DrawLine(o, tail[0], tail[2]);
                        g.DrawLine(o, tail[1], tail[2]);
                        g.DrawPath(o, p);
                        g.FillPath(wb, p);
                        g.DrawPath(o, p);
                        using (Pen cover = new Pen(Color.White, 2.6f))
                            g.DrawLine(cover, tail[0].X + 1.5f, baseY, tail[1].X - 1.5f, baseY);
                    }
                }
                using (SolidBrush tb = new SolidBrush(C("#1E1E1E")))
                    g.DrawString(text, f, tb, new RectangleF(x + 11, y + 6, sz.Width + 2, sz.Height + 2));
            }
        }

        // ------------------------- capa de efectos (pantalla completa) -------------------------
        static void FillQuad(Graphics g, Brush b, float cx, float cy, float w, float h, float rotDeg)
        {
            double r = rotDeg * Math.PI / 180.0;
            float c = (float)Math.Cos(r), s = (float)Math.Sin(r);
            float hw = w / 2, hh = h / 2;
            PointF[] q = {
                new PointF(cx - hw * c + hh * s, cy - hw * s - hh * c),
                new PointF(cx + hw * c + hh * s, cy + hw * s - hh * c),
                new PointF(cx + hw * c - hh * s, cy + hw * s + hh * c),
                new PointF(cx - hw * c - hh * s, cy - hw * s + hh * c) };
            g.FillPolygon(b, q);
        }

        static void OutlinedText(Graphics g, string text, float em, float cx, float cy, Color fill, int alpha)
        {
            using (GraphicsPath p = new GraphicsPath())
            using (FontFamily ff = new FontFamily("Segoe UI"))
            using (StringFormat sf = new StringFormat())
            {
                sf.Alignment = StringAlignment.Center; sf.LineAlignment = StringAlignment.Center;
                p.AddString(text, ff, (int)FontStyle.Bold, em, new PointF(cx, cy), sf);
                using (Pen o = new Pen(Color.FromArgb(alpha, 30, 20, 10), em * 0.12f))
                {
                    o.LineJoin = LineJoin.Round;
                    g.DrawPath(o, p);
                }
                using (SolidBrush b = new SolidBrush(Color.FromArgb(alpha, fill))) g.FillPath(b, p);
            }
        }

        Rectangle EffectsBox()
        {
            float x1 = float.MaxValue, y1 = float.MaxValue, x2 = float.MinValue, y2 = float.MinValue;
            Action<float, float, float, float> add = delegate(float x, float y, float rx, float ry)
            {
                if (x - rx < x1) x1 = x - rx; if (y - ry < y1) y1 = y - ry;
                if (x + rx > x2) x2 = x + rx; if (y + ry > y2) y2 = y + ry;
            };
            float k = S;
            foreach (Bullet b in bullets) add(b.X, b.Y, 45 * k, 45 * k);
            foreach (Hole h in holes) add(h.X, h.Y, 48 * k, 48 * k);
            foreach (Part p in parts) add(p.X, p.Y, p.Size * 1.6f + 4 * k, p.Size * 1.6f + 4 * k);
            foreach (Ring r in rings) add(r.X, r.Y, r.MaxR + 8 * k, r.MaxR + 8 * k);
            foreach (Popup pp in popups) add(pp.X, pp.Y, 140 * k, 45 * k);
            foreach (Splat sp in splats) { add(sp.X, sp.Y, 70 * k, 70 * k); add(sp.X, sp.Y + 80 * k, 30 * k, 10 * k); }
            foreach (Blob bl in blobs) add(bl.X, bl.Y, 60 * k, 60 * k);
            foreach (Grenade gr in grenades) add(gr.X, gr.Y, 30 * k, 30 * k);
            if (state == PetState.Dodge)
            {
                Rectangle ps = Scr().Bounds;
                add(ps.Left + ps.Width / 2f, ps.Top + 95 * k, 220 * k, 70 * k);
            }
            if (x1 > x2) return Rectangle.Empty;
            return Rectangle.FromLTRB((int)Math.Floor(x1), (int)Math.Floor(y1), (int)Math.Ceiling(x2), (int)Math.Ceiling(y2));
        }

        void DrawOverlay(Graphics g)
        {
            float ox = overlay.OX, oy = overlay.OY;

            // manchas de mantequilla
            foreach (Splat s in splats)
            {
                int a = (int)(255 * Math.Min(1f, s.Life / 2f));
                float age = s.MaxLife - s.Life;
                float x = s.X - ox, y = s.Y - oy;
                using (SolidBrush main = new SolidBrush(Color.FromArgb(a, 141, 85, 36)))
                using (SolidBrush hi = new SolidBrush(Color.FromArgb(a * 2 / 3, 198, 134, 66)))
                {
                    for (int i = 0; i < s.DX.Length; i++)
                    {
                        float dl = Math.Min(s.DL[i], age * 14f * S);
                        g.FillRectangle(main, x + s.DX[i] - 3 * S, y, 6 * S, dl);
                        g.FillEllipse(main, x + s.DX[i] - 4 * S, y + dl - 4 * S, 8 * S, 8 * S);
                    }
                    for (int i = 0; i < s.BR.Length; i++)
                        g.FillEllipse(main, x + s.BX[i] - s.BR[i], y + s.BY[i] - s.BR[i], s.BR[i] * 2, s.BR[i] * 2);
                    g.FillEllipse(hi, x - 12 * S, y - 14 * S, 14 * S, 9 * S);
                }
            }

            // agujeros de bala con el cristal agrietado
            foreach (Hole h in holes)
            {
                int a = (int)(255 * Math.Min(1f, h.Life / 1.5f));
                float x = h.X - ox, y = h.Y - oy;
                using (Pen shadow = new Pen(Color.FromArgb(a * 2 / 3, 20, 20, 25), 2.2f * S))
                using (Pen crack = new Pen(Color.FromArgb(a, 235, 238, 245), 1.3f * S))
                {
                    for (int i = 0; i < h.Ang.Length; i++)
                    {
                        float a1 = h.Ang[i], a2 = h.Ang[i] + 0.28f * (i % 2 == 0 ? 1 : -1);
                        PointF p0 = new PointF(x, y);
                        PointF p1 = new PointF(x + (float)Math.Cos(a1) * h.Len[i] * 0.5f, y + (float)Math.Sin(a1) * h.Len[i] * 0.5f);
                        PointF p2 = new PointF(p1.X + (float)Math.Cos(a2) * h.Len[i] * 0.5f, p1.Y + (float)Math.Sin(a2) * h.Len[i] * 0.5f);
                        PointF[] line = { p0, p1, p2 };
                        g.DrawLines(shadow, line);
                        g.DrawLines(crack, line);
                    }
                    float r1 = 9f * S;
                    g.DrawEllipse(crack, x - r1, y - r1, r1 * 2, r1 * 2);
                }
                float r = 4.5f * S;
                using (SolidBrush hole = new SolidBrush(Color.FromArgb(a, 18, 18, 22)))
                    g.FillEllipse(hole, x - r, y - r, r * 2, r * 2);
                using (Pen rim = new Pen(Color.FromArgb(a, 190, 190, 200), 1.4f * S))
                    g.DrawEllipse(rim, x - r, y - r, r * 2, r * 2);
            }

            // particulas
            foreach (Part p in parts)
            {
                float x = p.X - ox, y = p.Y - oy;
                int a = (int)(255 * Math.Min(1f, p.Life / 1f));
                switch (p.Kind)
                {
                    case K_SMOKE:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(Math.Min(130, a / 2), p.Col)))
                            g.FillEllipse(b, x - p.Size, y - p.Size, p.Size * 2, p.Size * 2);
                        break;
                    case K_CONFETTI:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, p.Col)))
                            FillQuad(g, b, x, y, p.Size, p.Size * 0.55f * (0.3f + Math.Abs((float)Math.Cos(p.Rot * 0.02f))), p.Rot);
                        break;
                    case K_DROP:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, p.Col)))
                            g.FillEllipse(b, x - p.Size / 2, y - p.Size / 2, p.Size, p.Size);
                        break;
                    case K_MAG:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, p.Col)))
                            FillQuad(g, b, x, y, p.Size, p.Size * 2.2f, p.Rot);
                        break;
                    case K_FRAG:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, p.Col)))
                            FillQuad(g, b, x, y, p.Size, p.Size * 0.5f, p.Rot);
                        break;
                    default:
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, p.Col)))
                            FillQuad(g, b, x, y, p.Size, p.Size * 0.45f, p.Rot);
                        break;
                }
            }

            // proyectiles de mantequilla
            foreach (Blob bl in blobs)
            {
                float x = bl.X - ox, y = bl.Y - oy;
                float sp = (float)Math.Sqrt(bl.VX * bl.VX + bl.VY * bl.VY);
                float nx = bl.VX / sp, ny = bl.VY / sp;
                using (SolidBrush tr = new SolidBrush(Color.FromArgb(90, 141, 85, 36)))
                    for (int i = 1; i <= 3; i++)
                    {
                        float rr = (12 - i * 2.5f) * S;
                        g.FillEllipse(tr, x - nx * i * 14 * S - rr, y - ny * i * 14 * S - rr, rr * 2, rr * 2);
                    }
                float r = 12 * S;
                using (SolidBrush b = new SolidBrush(C("#8D5524"))) g.FillEllipse(b, x - r, y - r, r * 2, r * 2);
                using (SolidBrush hi = new SolidBrush(Color.FromArgb(160, 230, 180, 120))) g.FillEllipse(hi, x - r * 0.6f, y - r * 0.7f, r * 0.7f, r * 0.5f);
            }

            // granadas de pipa
            foreach (Grenade gr in grenades)
            {
                DrawPipa(g, gr.X - ox, gr.Y - oy, gr.Rot, 1.4f * S);
                if (((int)(gr.Fuse * 8)) % 2 == 0)
                    using (SolidBrush spark = new SolidBrush(Color.FromArgb(230, 255, 200, 60)))
                        g.FillEllipse(spark, gr.X - ox - 3 * S, gr.Y - oy - 14 * S, 6 * S, 6 * S);
            }

            // balas
            using (SolidBrush head = new SolidBrush(C("#FFD54A")))
            using (SolidBrush headGame = new SolidBrush(C("#FF5252")))
            using (Pen trail = new Pen(Color.FromArgb(110, 255, 225, 140), 2.2f * S))
            {
                trail.StartCap = LineCap.Round; trail.EndCap = LineCap.Round;
                foreach (Bullet bu in bullets)
                {
                    float x = bu.X - ox, y = bu.Y - oy;
                    float sp = (float)Math.Sqrt(bu.VX * bu.VX + bu.VY * bu.VY);
                    float nx = bu.VX / sp, ny = bu.VY / sp;
                    g.DrawLine(trail, x - nx * 34 * S, y - ny * 34 * S, x, y);
                    float hr = 3f * S;
                    g.FillEllipse(bu.Game ? headGame : head, x - hr, y - hr, hr * 2, hr * 2);
                }
            }

            // explosiones
            foreach (Ring rg in rings)
            {
                float prog = 1f - rg.Life / rg.MaxLife;
                float r = rg.MaxR * (0.3f + 0.7f * prog);
                float x = rg.X - ox, y = rg.Y - oy;
                using (SolidBrush fill = new SolidBrush(Color.FromArgb((int)(170 * (1 - prog)), 255, 152, 0)))
                    g.FillEllipse(fill, x - r, y - r, r * 2, r * 2);
                using (SolidBrush core = new SolidBrush(Color.FromArgb((int)(220 * (1 - prog)), 255, 235, 120)))
                    g.FillEllipse(core, x - r * 0.5f, y - r * 0.5f, r, r);
                using (Pen ring = new Pen(Color.FromArgb((int)(230 * (1 - prog)), 255, 255, 255), 4 * S))
                    g.DrawEllipse(ring, x - r, y - r, r * 2, r * 2);
            }

            // textos de comic
            foreach (Popup pp in popups)
            {
                float prog = 1f - pp.Life / pp.MaxLife;
                int a = (int)(255 * Math.Min(1f, pp.Life / 0.4f));
                OutlinedText(g, pp.Text, 34 * S * (1f + 0.3f * prog), pp.X - ox, pp.Y - oy, pp.Col, a);
            }

            // marcador del minijuego
            if (state == PetState.Dodge)
            {
                Rectangle psb = Scr().Bounds;
                float cx = psb.Left + psb.Width / 2f - ox;
                float hy = psb.Top - oy;
                string big = dodgeRunning ? dodgeTime.ToString("0.0") + " s" : (dodgeCountdown > 0 ? ((int)Math.Ceiling(dodgeCountdown)).ToString() : "¡YA!");
                OutlinedText(g, big, 54 * S, cx, hy + 70 * S, Color.FromArgb(255, 213, 74), 255);
                OutlinedText(g, "Récord: " + bestDodge.ToString("0.0") + " s", 22 * S, cx, hy + 120 * S, Color.White, 230);
            }
        }

        // ================================ sonido ================================
        void PlaySamples(double[] buf, int sr)
        {
            try
            {
                double peak = 0.0001;
                for (int i = 0; i < buf.Length; i++) peak = Math.Max(peak, Math.Abs(buf[i]));
                double gain = 0.35 / peak;
                int n = buf.Length;
                MemoryStream ms = new MemoryStream();
                BinaryWriter w = new BinaryWriter(ms);
                w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + n * 2);
                w.Write(Encoding.ASCII.GetBytes("WAVE"));
                w.Write(Encoding.ASCII.GetBytes("fmt ")); w.Write(16); w.Write((short)1); w.Write((short)1);
                w.Write(sr); w.Write(sr * 2); w.Write((short)2); w.Write((short)16);
                w.Write(Encoding.ASCII.GetBytes("data")); w.Write(n * 2);
                for (int i = 0; i < n; i++) w.Write((short)(Math.Max(-1, Math.Min(1, buf[i] * gain)) * 32767));
                w.Flush();
                ms.Position = 0;
                player = new SoundPlayer(ms);
                player.Play();
                lastSoundTime = t;
            }
            catch { }
        }

        void PlayBurst(int shots, double interval)
        {
            int sr = 22050;
            int n = (int)(sr * (shots * interval + 0.3));
            double[] buf = new double[n];
            Random r = new Random();
            int shotLen = (int)(0.14 * sr);
            for (int s = 0; s < shots; s++)
            {
                int start = (int)(s * interval * sr);
                double last = 0;
                for (int i = 0; i < shotLen && start + i < n; i++)
                {
                    double tt = (double)i / sr;
                    last = last * 0.55 + (r.NextDouble() * 2 - 1) * 0.45;
                    double crack = last * Math.Exp(-tt / 0.018);
                    double thump = Math.Sin(2 * Math.PI * (120 - 250 * tt) * tt) * Math.Exp(-tt / 0.04);
                    buf[start + i] += crack * 0.8 + thump * 0.6;
                }
            }
            PlaySamples(buf, sr);
        }

        void PlayBoom()
        {
            int sr = 22050, n = (int)(sr * 1.0);
            double[] buf = new double[n];
            Random r = new Random();
            double last = 0;
            for (int i = 0; i < n; i++)
            {
                double tt = (double)i / sr;
                last = last * 0.93 + (r.NextDouble() * 2 - 1) * 0.07;
                buf[i] = last * 4 * Math.Exp(-tt / 0.25) + Math.Sin(2 * Math.PI * (60 - 30 * tt) * tt) * Math.Exp(-tt / 0.3);
            }
            PlaySamples(buf, sr);
        }

        void PlayThump()
        {
            int sr = 22050, n = (int)(sr * 0.5);
            double[] buf = new double[n];
            Random r = new Random();
            for (int i = 0; i < n; i++)
            {
                double tt = (double)i / sr;
                buf[i] = Math.Sin(2 * Math.PI * (95 - 120 * tt) * tt) * Math.Exp(-tt / 0.09) + (r.NextDouble() * 2 - 1) * Math.Exp(-tt / 0.03) * 0.5;
            }
            PlaySamples(buf, sr);
        }

        void PlayPop()
        {
            int sr = 22050, n = (int)(sr * 0.3);
            double[] buf = new double[n];
            Random r = new Random();
            for (int i = 0; i < n; i++)
            {
                double tt = (double)i / sr;
                buf[i] = (r.NextDouble() * 2 - 1) * Math.Exp(-tt / 0.012) + Math.Sin(2 * Math.PI * 700 * tt) * Math.Exp(-tt / 0.05) * 0.3;
            }
            PlaySamples(buf, sr);
        }

        void OnDisplayChanged(object sender, EventArgs e)
        {
            try { BeginInvoke((MethodInvoker)delegate { DisplayChanged(); }); } catch { }
        }

        void DisplayChanged()
        {
            Log.W("pantallas cambiadas: " + Screen.AllScreens.Length + " escritorio=" + SystemInformation.VirtualScreen);
            overlay.Reset();
            if (buddy != null) buddy.Drop();
            bullets.Clear(); holes.Clear(); parts.Clear(); splats.Clear(); blobs.Clear(); grenades.Clear(); rings.Clear(); popups.Clear();
            px = Math.Max(MinX(), Math.Min(MaxX(), px));
            if (state != PetState.Drag && state != PetState.Crazy)
            {
                Rectangle b = Screen.PrimaryScreen.Bounds;
                bool lost = true;
                foreach (Screen sc in Screen.AllScreens) if (sc.Bounds.Contains((int)px, (int)(py - 5 * S))) lost = false;
                if (lost) { px = b.Left + b.Width * 0.5f; py = b.Bottom - 2 * S; }
                BeginFall(0, 0);
                if (lost) py = b.Top + 100 * S;
            }
            SayAlways(Screen.AllScreens.Length > 1 ? "¡Nueva pantalla detectada! A explorar." : "Vuelta a una sola pantalla.", 3f);
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            SystemEvents.DisplaySettingsChanged -= OnDisplayChanged;
            timer.Stop();
            try { diary.Save(); } catch { }
            try { if (sprites != null) sprites.Dispose(); } catch { }
            try { if (buddy != null) buddy.Close(); } catch { }
            try { if (settingsWin != null && !settingsWin.IsDisposed) settingsWin.Close(); } catch { }
            try { overlay.Close(); } catch { }
            base.OnFormClosed(e);
        }
    }

    // Arranque automatico: acceso directo en la carpeta Inicio de tu usuario
    // (Kaspersky bloquea en silencio la clave Run del registro, asi que usamos la carpeta).
    public static class AutoStart
    {
        const string RUN_KEY = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string APP_KEY = @"Software\CacahueteComando";
        const string VALUE = "CacahueteComando";
        public static string ScriptPath;
        public static bool IsExe;

        static string LinkPath()
        {
            return System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), "Cacahuete Comando.lnk");
        }

        static void Target(out string file, out string args)
        {
            if (IsExe) { file = ScriptPath; args = ""; return; }
            file = "powershell.exe";
            args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ScriptPath + "\"";
        }

        public static bool IsOn() { return File.Exists(LinkPath()); }

        static void MakeLink()
        {
            string file, args;
            Target(out file, out args);
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object sh = Activator.CreateInstance(t);
            try
            {
                object lnk = t.InvokeMember("CreateShortcut", System.Reflection.BindingFlags.InvokeMethod, null, sh, new object[] { LinkPath() });
                Type lt = lnk.GetType();
                lt.InvokeMember("TargetPath", System.Reflection.BindingFlags.SetProperty, null, lnk, new object[] { file });
                lt.InvokeMember("Arguments", System.Reflection.BindingFlags.SetProperty, null, lnk, new object[] { args });
                lt.InvokeMember("WorkingDirectory", System.Reflection.BindingFlags.SetProperty, null, lnk, new object[] { System.IO.Path.GetDirectoryName(ScriptPath) });
                lt.InvokeMember("Description", System.Reflection.BindingFlags.SetProperty, null, lnk, new object[] { "Cacahuete Comando" });
                lt.InvokeMember("WindowStyle", System.Reflection.BindingFlags.SetProperty, null, lnk, new object[] { 7 });
                lt.InvokeMember("Save", System.Reflection.BindingFlags.InvokeMethod, null, lnk, null);
                Marshal.ReleaseComObject(lnk);
            }
            finally { Marshal.ReleaseComObject(sh); }
        }

        public static void Set(bool on)
        {
            try
            {
                if (on) MakeLink();
                else if (File.Exists(LinkPath())) File.Delete(LinkPath());
                Log.W("acceso directo de inicio " + (on ? "creado" : "borrado") + ": " + LinkPath() + " existe=" + File.Exists(LinkPath()));
            }
            catch (Exception ex) { Log.W("ERROR con el acceso directo de inicio: " + ex.Message); }
            // limpiar la entrada antigua del registro
            try { using (RegistryKey k = Registry.CurrentUser.OpenSubKey(RUN_KEY, true)) if (k != null) k.DeleteValue(VALUE, false); } catch { }
            try { using (RegistryKey a = Registry.CurrentUser.CreateSubKey(APP_KEY)) a.SetValue("AutoStartOff", on ? 0 : 1, RegistryValueKind.DWord); } catch { }
        }

        // Primera vez: se activa solo. Si lo apagaste desde el menu, se respeta.
        // Se rehace en cada arranque por si moviste la carpeta.
        public static void EnsureOnLaunch()
        {
            if (string.IsNullOrEmpty(ScriptPath)) return;
            try
            {
                bool off = false;
                using (RegistryKey a = Registry.CurrentUser.OpenSubKey(APP_KEY))
                    if (a != null) { object v = a.GetValue("AutoStartOff"); off = v != null && Convert.ToInt32(v) == 1; }
                if (!off) Set(true);
            }
            catch (Exception ex) { Log.W("ERROR arranque automatico: " + ex.Message); }
        }
    }

    public static class Program
    {
        static string Ps1() { return System.IO.Path.Combine(System.IO.Path.GetDirectoryName(AutoStart.ScriptPath), "cacahuete.ps1"); }

        // el .exe se rehace solo si cacahuete.ps1 es mas nuevo
        public static bool NeedsUpdate()
        {
            if (!AutoStart.IsExe) return false;
            try
            {
                string ps = Ps1();
                if (!File.Exists(ps)) return false;
                return File.GetLastWriteTimeUtc(ps) > File.GetLastWriteTimeUtc(AutoStart.ScriptPath).AddSeconds(2);
            }
            catch { return false; }
        }

        public static void StartRebuild()
        {
            try
            {
                System.Diagnostics.ProcessStartInfo psi = new System.Diagnostics.ProcessStartInfo("powershell.exe",
                    "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + Ps1() + "\" -Build -Silent");
                psi.UseShellExecute = false; psi.CreateNoWindow = true;
                psi.WorkingDirectory = System.IO.Path.GetDirectoryName(AutoStart.ScriptPath);
                System.Diagnostics.Process.Start(psi);
                Log.W("actualizando: rehaciendo Cacahuete.exe");
            }
            catch (Exception ex) { Log.W("ERROR al actualizar: " + ex.Message); }
        }

        [STAThread]
        public static void Main(string[] args) { Run(Application.ExecutablePath, true); }

        public static void Run(string scriptPath) { Run(scriptPath, false); }

        public static void Run(string scriptPath, bool isExe)
        {
            AutoStart.ScriptPath = scriptPath;
            AutoStart.IsExe = isExe;
            try { Log.Path = System.IO.Path.Combine(System.IO.Path.GetDirectoryName(scriptPath), "cacahuete-log.txt"); } catch { }
            Log.W("Run() arrancado");
            if (NeedsUpdate()) { StartRebuild(); return; }
            bool created;
            using (Mutex mx = new Mutex(true, "CacahueteComando_UnicaInstancia", out created))
            {
                if (!created) { Log.W("ya habia otro cacahuete abierto; salgo"); return; }
                Log.W("paso 1: instancia unica OK");
                AutoStart.EnsureOnLaunch();
                Log.W("paso 2: arranque con Windows OK");
                Native.MakeDpiAware();
                try { System.Diagnostics.Process.GetCurrentProcess().PriorityClass = System.Diagnostics.ProcessPriorityClass.BelowNormal; } catch { }
                try { Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException); } catch { }
                Application.ThreadException += delegate(object o, ThreadExceptionEventArgs ev) { Log.W("ERROR: " + ev.Exception); };
                Application.EnableVisualStyles();
                Log.W("paso 3: creando el cacahuete");
                try { Application.Run(new PetForm()); }
                catch (Exception ex) { Log.W("ERROR fatal: " + ex); }
                Log.W("cerrado");
            }
        }
    }
}
'@

if ($Build) {
    $exe = Join-Path $PSScriptRoot 'Cacahuete.exe'
    Write-Host ""
    Write-Host "  Montando el Cacahuete Comando..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 800
    Get-Process -Name Cacahuete -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    try {
        Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms, System.Drawing `
            -OutputAssembly $exe -OutputType WindowsApplication -IgnoreWarnings -ErrorAction Stop
        Write-Host "  ¡Listo! Arrancando el cacahuete..." -ForegroundColor Green
        Start-Process -FilePath $exe -WorkingDirectory $PSScriptRoot
        Start-Sleep -Seconds 2
    }
    catch {
        $err = $_ | Out-String
        "==== $(Get-Date) ERROR al montar el exe`r`n$err" | Out-File (Join-Path $PSScriptRoot 'cacahuete-log.txt') -Append -Encoding utf8
        if ($Silent) {
            # vuelve a abrir la version anterior y evita reintentar en bucle
            if (Test-Path $exe) {
                (Get-Item $exe).LastWriteTime = Get-Date
                Start-Process -FilePath $exe -WorkingDirectory $PSScriptRoot
            }
        } else {
            Write-Host "  Algo ha fallado:" -ForegroundColor Red
            Write-Host $err
            Read-Host "  Pulsa Enter para cerrar"
        }
    }
    return
}

$log = Join-Path $PSScriptRoot 'cacahuete-log.txt'
"==== $(Get-Date)  PowerShell $($PSVersionTable.PSVersion)  $PSCommandPath" | Out-File $log -Encoding utf8
try {
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms, System.Drawing -IgnoreWarnings -ErrorAction Stop
    "compilado OK" | Out-File $log -Append -Encoding utf8
    [Cacahuete.Program]::Run($PSCommandPath)
}
catch {
    "ERROR PowerShell: $($_ | Out-String)" | Out-File $log -Append -Encoding utf8
    ($Error | Out-String) | Out-File $log -Append -Encoding utf8
}
