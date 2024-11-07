param (
    [string]$functionName = $args[0],        # Name of the function to call
    [string]$screenshotPath = $args[1]       # Path for saving the screenshot
)

function customscreen {
    param (
        [string]$screenshotPath 
    )
    Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class ScreenCaptureForm : Form {
    public Rectangle SelectionRectangle { get; private set; }
    private Point startPoint;
    private bool isSelecting = false;

    public ScreenCaptureForm() {
        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor = Color.Black;
        this.Opacity = 0.3;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.DoubleBuffered = true;
        this.Cursor = Cursors.Cross;

        this.MouseDown += new MouseEventHandler(StartSelection);
        this.MouseMove += new MouseEventHandler(UpdateSelection);
        this.MouseUp += new MouseEventHandler(EndSelection);
    }

    private void StartSelection(object sender, MouseEventArgs e) {
        startPoint = e.Location;
        isSelecting = true;
    }

    private void UpdateSelection(object sender, MouseEventArgs e) {
        if (isSelecting) {
            int x = Math.Min(e.X, startPoint.X);
            int y = Math.Min(e.Y, startPoint.Y);
            int width = Math.Abs(e.X - startPoint.X);
            int height = Math.Abs(e.Y - startPoint.Y);
            SelectionRectangle = new Rectangle(x, y, width, height);
            this.Invalidate();
        }
    }

    private void EndSelection(object sender, MouseEventArgs e) {
        isSelecting = false;
        this.DialogResult = DialogResult.OK;
        this.Close();
    }

    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        if (isSelecting) {
            using (Pen pen = new Pen(Color.Red, 2)) {
                e.Graphics.DrawRectangle(pen, SelectionRectangle);
            }
        }
    }

    public static Rectangle SelectArea() {
        using (ScreenCaptureForm form = new ScreenCaptureForm()) {
            return form.ShowDialog() == DialogResult.OK ? form.SelectionRectangle : Rectangle.Empty;
        }
    }
}

public class ScreenCapture {
    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowDC(IntPtr hwnd);
    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
    [DllImport("gdi32.dll")]
    public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
    [DllImport("gdi32.dll")]
    public static extern bool BitBlt(IntPtr hdcDest, int nXDest, int nYDest, int nWidth, int nHeight,
        IntPtr hdcSrc, int nXSrc, int nYSrc, int dwRop);
    [DllImport("gdi32.dll")]
    public static extern bool DeleteObject(IntPtr hObject);
    [DllImport("gdi32.dll")]
    public static extern bool DeleteDC(IntPtr hdc);
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
    
    public const int SRCCOPY = 0x00CC0020;

    public static void CaptureArea(string filePath, int x, int y, int width, int height) {
        IntPtr desktopWnd = GetDesktopWindow();
        IntPtr desktopDC = GetWindowDC(desktopWnd);
        IntPtr memoryDC = CreateCompatibleDC(desktopDC);

        IntPtr bitmap = CreateCompatibleBitmap(desktopDC, width, height);
        IntPtr oldBitmap = SelectObject(memoryDC, bitmap);

        BitBlt(memoryDC, 0, 0, width, height, desktopDC, x, y, SRCCOPY);

        System.Drawing.Bitmap img = System.Drawing.Image.FromHbitmap(bitmap);
        img.Save(filePath, System.Drawing.Imaging.ImageFormat.Png);

        SelectObject(memoryDC, oldBitmap);
        DeleteObject(bitmap);
        DeleteDC(memoryDC);
        ReleaseDC(desktopWnd, desktopDC);
    }

    public static void CaptureScreen(string filePath) {
        IntPtr desktopWnd = GetDesktopWindow();
        IntPtr desktopDC = GetWindowDC(desktopWnd);
        IntPtr memoryDC = CreateCompatibleDC(desktopDC);
        
        int width = System.Windows.Forms.Screen.PrimaryScreen.Bounds.Width;
        int height = System.Windows.Forms.Screen.PrimaryScreen.Bounds.Height;
        
        IntPtr bitmap = CreateCompatibleBitmap(desktopDC, width, height);
        IntPtr oldBitmap = SelectObject(memoryDC, bitmap);

        BitBlt(memoryDC, 0, 0, width, height, desktopDC, 0, 0, SRCCOPY);

        System.Drawing.Bitmap img = System.Drawing.Image.FromHbitmap(bitmap);
        img.Save(filePath, System.Drawing.Imaging.ImageFormat.Png);

        SelectObject(memoryDC, oldBitmap);
        DeleteObject(bitmap);
        DeleteDC(memoryDC);
        ReleaseDC(desktopWnd, desktopDC);
    }
}
"@ -ReferencedAssemblies System.Drawing, System.Windows.Forms

    # Prompt the user to select an area of the screen
    $selection = [ScreenCaptureForm]::SelectArea()

    if ($selection -ne [System.Drawing.Rectangle]::Empty) {
        [ScreenCapture]::CaptureArea($screenshotPath, $selection.X, $selection.Y, $selection.Width, $selection.Height)
        #Write-Output "`nScreenshot of specified area saved to $screenshotPath"
    }
    #else {
    #    Write-Output "`nNo area selected."
    #}
}

function fullscreen {
    param (
        [string]$screenshotPath 
    )
    # Check if the type is already defined
    $typeName = "ScreenCapture"
    $existingType = [AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.GetTypes() | Where-Object { $_.Name -eq $typeName } }

    # If the type does not exist, define it
    if (-not $existingType) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Windows.Forms;

public class ScreenCapture {
    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowDC(IntPtr hwnd);

    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateCompatibleDC(IntPtr hdc);

    [DllImport("gdi32.dll")]
    public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);

    [DllImport("gdi32.dll")]
    public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);

    [DllImport("gdi32.dll")]
    public static extern bool BitBlt(IntPtr hdcDest, int nXDest, int nYDest, int nWidth, int nHeight,
        IntPtr hdcSrc, int nXSrc, int nYSrc, int dwRop);

    [DllImport("gdi32.dll")]
    public static extern bool DeleteObject(IntPtr hObject);

    [DllImport("gdi32.dll")]
    public static extern bool DeleteDC(IntPtr hdc);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);

    public const int SRCCOPY = 0x00CC0020;

    public static void CaptureScreen(string filePath) {
        IntPtr desktopWnd = GetDesktopWindow();
        IntPtr desktopDC = GetWindowDC(desktopWnd);
        IntPtr memoryDC = CreateCompatibleDC(desktopDC);
        
        int width = Screen.PrimaryScreen.Bounds.Width;
        int height = Screen.PrimaryScreen.Bounds.Height;
        
        IntPtr bitmap = CreateCompatibleBitmap(desktopDC, width, height);
        IntPtr oldBitmap = SelectObject(memoryDC, bitmap);

        BitBlt(memoryDC, 0, 0, width, height, desktopDC, 0, 0, SRCCOPY);

        Bitmap img = Image.FromHbitmap(bitmap);
        img.Save(filePath, System.Drawing.Imaging.ImageFormat.Png);

        SelectObject(memoryDC, oldBitmap);
        DeleteObject(bitmap);
        DeleteDC(memoryDC);
        ReleaseDC(desktopWnd, desktopDC);
    }
}
"@ -ReferencedAssemblies System.Drawing, System.Windows.Forms
    }

    # Capture and save the screen
    [ScreenCapture]::CaptureScreen($screenshotPath)

   # Write-Output "`nScreenshot saved to $screenshotPath"
}


switch ($functionName) {
    "customscreen" { customscreen -screenshotPath $screenshotPath }
    "fullscreen" { fullscreen -screenshotPath $screenshotPath }
    default { Write-Output "Invalid function name provided." }
}