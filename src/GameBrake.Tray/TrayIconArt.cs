using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace GameBrake.Tray;

/// <summary>
/// Draws the tray icon, countdown and all.
/// </summary>
/// <remarks>
/// The number lives in the picture rather than in the tooltip because the shell
/// reads a notify icon tooltip once, when it appears, and never again while it is
/// on screen. A countdown there stands still until the pointer leaves and comes
/// back. Redrawing the icon updates in place, and asks for no pointer at all,
/// which is closer to what AC8 wants than a tooltip ever was.
/// </remarks>
internal static class TrayIconArt
{
    private static readonly Color Waiting = Color.FromArgb(198, 62, 62);
    private static readonly Color Open = Color.FromArgb(46, 143, 74);

    /// <summary>Nothing is counting: the brake at rest.</summary>
    public static Icon AtRest() => Render(Waiting, label: null, remainingFraction: null);

    /// <summary>
    /// A countdown, as a depleting ring with at most one figure inside it.
    /// </summary>
    /// <remarks>
    /// One figure, never two, and always minutes rounded up. The shell asks for
    /// sixteen pixels, and two digits rendered into that come out as a smudge:
    /// drawn and checked, 59 and 28 were unreadable while 5 and 9 were clear.
    /// Seconds therefore cannot be shown, and an attempt to show nothing at all
    /// under a minute left a blank disc that read as a broken icon. So it counts
    /// 5, 4, 3, 2, 1 and then turns green, and the exact figure stays in the
    /// tooltip and the menu.
    /// <para>
    /// The ring sweeps the seconds within the current minute rather than the whole
    /// cooldown, which is what makes it move at all. Against a five minute total it
    /// would travel a third of a percent per second and stand visibly still; a
    /// minute of it travels one part in sixty. Digit for minutes, ring for seconds,
    /// the way a clock does it.
    /// </para>
    /// </remarks>
    public static Icon Countdown(TimeSpan remaining, bool permitted)
    {
        var seconds = Math.Max(0, (int)Math.Ceiling(remaining.TotalSeconds));
        var minutes = Math.Max(1, (seconds + 59) / 60);

        // Past nine minutes there is no single digit to show, so the ring alone.
        var label = minutes <= 9 ? minutes.ToString() : null;

        var withinMinute = seconds % 60;
        var fraction = withinMinute == 0 ? 1d : withinMinute / 60d;

        return Render(permitted ? Open : Waiting, label, fraction);
    }

    private static Icon Render(Color disc, string? label, double? remainingFraction)
    {
        // Drawn at whatever the shell actually asks for, so nothing is resampled.
        var size = Math.Max(16, SystemInformation.SmallIconSize.Width);
        var scale = size / 32f;

        using var bitmap = new Bitmap(size, size);
        using (var canvas = Graphics.FromImage(bitmap))
        {
            canvas.SmoothingMode = SmoothingMode.AntiAlias;
            canvas.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            canvas.Clear(Color.Transparent);

            using (var body = new SolidBrush(disc))
            {
                canvas.FillEllipse(body, 0.5f, 0.5f, size - 1.5f, size - 1.5f);
            }

            if (remainingFraction is { } left)
            {
                // The track is a darker shade of the disc rather than a pale wash
                // of white. Translucent white over red loses against the antialiased
                // edge and reads as nothing at all at this size, which is what the
                // first attempt did.
                var inset = 1.5f * scale;
                var box = new RectangleF(inset, inset, size - (inset * 2), size - (inset * 2));
                var width = 4f * scale;

                using var spent = new Pen(Darken(disc, 0.55f), width);
                canvas.DrawEllipse(spent, box);

                using var owed = new Pen(Color.White, width);
                canvas.DrawArc(owed, box, -90f, (float)(360d * left));
            }

            if (label is null && remainingFraction is null)
            {
                using var bars = new SolidBrush(Color.White);
                canvas.FillRectangle(bars, 10f * scale, 9f * scale, 4f * scale, 14f * scale);
                canvas.FillRectangle(bars, 18f * scale, 9f * scale, 4f * scale, 14f * scale);
            }
            else if (label is not null)
            {
                using var font = new Font("Segoe UI", 20f * scale, FontStyle.Bold, GraphicsUnit.Pixel);
                using var centred = new StringFormat
                {
                    Alignment = StringAlignment.Center,
                    LineAlignment = StringAlignment.Center,
                };

                canvas.DrawString(
                    label, font, Brushes.White, new RectangleF(0, 0, size, size), centred);
            }
        }

        return FromBitmap(bitmap);
    }

    private static Color Darken(Color colour, float factor) => Color.FromArgb(
        colour.A,
        (int)(colour.R * factor),
        (int)(colour.G * factor),
        (int)(colour.B * factor));

    private static Icon FromBitmap(Bitmap bitmap)
    {
        var handle = bitmap.GetHicon();
        try
        {
            using var borrowed = Icon.FromHandle(handle);

            // Clone, so what is returned owns itself and outlives the handle.
            return (Icon)borrowed.Clone();
        }
        finally
        {
            NativeMethods.DestroyIcon(handle);
        }
    }
}
