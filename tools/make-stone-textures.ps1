# Draws the stone set that replaced the four mockup cut-outs.
#
#   powershell -ExecutionPolicy Bypass -File tools\make-stone-textures.ps1
#
# Writes assets/props/{masonry,sigil_block,conduit}.png. Committed, like every
# other painted asset -- this script exists so the drawing can be changed and
# regenerated, not so the build has to run it.
#
# WHY A TEXTURE. These three were drawn with Node2D draw calls for one release
# and it cost 1-1 eighty draw calls and a 48ms frame; drawn cheaply enough to
# be fast, they looked like grey boxes. A sprite is one quad however detailed
# the picture is, which is why the art it replaced was a sprite. Detail is
# free here and expensive there.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "assets\props"

function New-Canvas([int]$w, [int]$h) {
  $b = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  ,@($b, $g)
}
function C([int]$a, [string]$hex) {
  $r = [Convert]::ToInt32($hex.Substring(0,2),16)
  $gg = [Convert]::ToInt32($hex.Substring(2,2),16)
  $bb = [Convert]::ToInt32($hex.Substring(4,2),16)
  [System.Drawing.Color]::FromArgb($a,$r,$gg,$bb)
}
function Brush($c) { New-Object System.Drawing.SolidBrush $c }
function Pen($c, [single]$w) { New-Object System.Drawing.Pen $c, $w }

# Weathering: a handful of soft blotches, hashed so the same file comes out of
# the same script every time rather than drifting each run.
function Add-Mottle($g, [int]$w, [int]$h, [int]$seed, [int]$count) {
  $rand = New-Object System.Random $seed
  for ($i = 0; $i -lt $count; $i++) {
    $rx = $rand.Next(0, $w); $ry = $rand.Next(0, $h)
    $rr = $rand.Next([int]($w * 0.06), [int]($w * 0.20))
    $a = $rand.Next(8, 20)
    $dark = $rand.Next(0, 2) -eq 0
    $col = if ($dark) { C $a "5b544a" } else { C $a "ffffff" }
    $g.FillEllipse((Brush $col), ($rx - $rr), ($ry - $rr * 0.7), ($rr * 2), ($rr * 1.4))
  }
}

# ---------------------------------------------------------------- masonry ---
# Coursed stone: three courses, joints offset, a lit top edge and a shaded
# right edge so a row of them reads as depth rather than as flat panels.
function New-Masonry([int]$size, [bool]$sigil) {
  $pair = New-Canvas $size $size
  $b = $pair[0]; $g = $pair[1]
  $g.FillRectangle((Brush (C 255 "9a9084")), 0, 0, $size, $size)

  $rows = 3
  $rh = $size / $rows
  for ($r = 0; $r -lt $rows; $r++) {
    $y = $r * $rh
    # Each stone in the course gets its own very slightly different tone.
    $tone = @("a4998c","93897d","9e9488")[$r % 3]
    $g.FillRectangle((Brush (C 255 $tone)), 0, [int]$y, $size, [int]$rh)
    # lit top of the course, shadow under it
    $g.FillRectangle((Brush (C 46 "ffffff")), 0, [int]$y, $size, 3)
    $g.FillRectangle((Brush (C 60 "4f483f")), 0, [int]($y + $rh - 3), $size, 3)
    # the joint, offset every other course
    $jx = if ($r % 2 -eq 0) { $size * 0.5 } else { $size * 0.24 }
    $g.DrawLine((Pen (C 90 "4f483f") 3), [single]$jx, [single]($y + 3), [single]$jx, [single]($y + $rh - 3))
    $g.DrawLine((Pen (C 40 "ffffff") 1), [single]($jx + 2), [single]($y + 3), [single]($jx + 2), [single]($y + $rh - 3))
  }

  Add-Mottle $g $size $size 20260927 14

  # The block's own edges: light on top and left, dark on the right.
  $g.FillRectangle((Brush (C 64 "ffffff")), 0, 0, $size, 4)
  $g.FillRectangle((Brush (C 40 "ffffff")), 0, 0, 4, $size)
  $g.FillRectangle((Brush (C 74 "3f3a33")), $size - 6, 0, 6, $size)
  $g.FillRectangle((Brush (C 90 "3f3a33")), 0, $size - 5, $size, 5)
  $g.DrawRectangle((Pen (C 70 "3a352e") 2), 1, 1, $size - 3, $size - 3)

  if ($sigil) {
    # A lozenge cut into the face, with gold left in the groove.
    $cx = $size / 2.0; $cy = $size / 2.0
    $w = $size * 0.26; $h = $size * 0.30
    $pts = @(
      (New-Object System.Drawing.PointF ([single]$cx, [single]($cy - $h))),
      (New-Object System.Drawing.PointF ([single]($cx + $w), [single]$cy)),
      (New-Object System.Drawing.PointF ([single]$cx, [single]($cy + $h))),
      (New-Object System.Drawing.PointF ([single]($cx - $w), [single]$cy))
    )
    $shadow = $pts | ForEach-Object { New-Object System.Drawing.PointF ([single]($_.X), [single]($_.Y + 3)) }
    $g.FillPolygon((Brush (C 120 "2f2a24")), [System.Drawing.PointF[]]$shadow)
    $g.FillPolygon((Brush (C 235 "241f1a")), [System.Drawing.PointF[]]$pts)
    $inner = $pts | ForEach-Object {
      New-Object System.Drawing.PointF ([single]($cx + ($_.X - $cx) * 0.55), [single]($cy + ($_.Y - $cy) * 0.55))
    }
    $g.FillPolygon((Brush (C 255 "d9ab55")), [System.Drawing.PointF[]]$inner)
    $g.FillPolygon((Brush (C 70 "fff0c0")), [System.Drawing.PointF[]](
      $inner[0], $inner[1],
      (New-Object System.Drawing.PointF ([single]$cx, [single]$cy))))
  }
  $g.Dispose()
  $b
}

# ---------------------------------------------------------------- conduit ---
# A stone conduit: a shaft that narrows to a flat collar with a dark mouth.
# Drawn into its own alpha so the taper is a real silhouette, not a box.
function New-Conduit([int]$w, [int]$h) {
  $pair = New-Canvas $w $h
  $b = $pair[0]; $g = $pair[1]
  $collar = [int]($h * 0.20)
  $inset = [int]($w * 0.10)

  $shaft = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ([single]0, [single]$h)),
    (New-Object System.Drawing.PointF ([single]$inset, [single]$collar)),
    (New-Object System.Drawing.PointF ([single]($w - $inset), [single]$collar)),
    (New-Object System.Drawing.PointF ([single]$w, [single]$h))
  )
  $g.FillPolygon((Brush (C 255 "8d8577")), $shaft)

  # courses down the shaft
  $y = $collar + [int]($h * 0.14)
  while ($y -lt $h - 6) {
    $t = ($y - $collar) / [single]($h - $collar)
    $l = $inset * (1 - $t); $r = $w - $inset * (1 - $t)
    $g.DrawLine((Pen (C 70 "554e45") 3), [single]($l + 3), [single]$y, [single]($r - 3), [single]$y)
    $g.DrawLine((Pen (C 40 "ffffff") 1), [single]($l + 3), [single]($y + 3), [single]($r - 3), [single]($y + 3))
    $y += [int]($h * 0.14)
  }
  Add-Mottle $g $w $h 927 10

  # lit left face and shaded right face
  $lit = [System.Drawing.PointF[]]@(
    $shaft[0], $shaft[1],
    (New-Object System.Drawing.PointF ([single]($inset + $w * 0.18), [single]$collar)),
    (New-Object System.Drawing.PointF ([single]($w * 0.20), [single]$h))
  )
  $g.FillPolygon((Brush (C 34 "ffffff")), $lit)
  $shade = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ([single]($w - $inset - $w * 0.20), [single]$collar)),
    $shaft[2], $shaft[3],
    (New-Object System.Drawing.PointF ([single]($w - $w * 0.22), [single]$h))
  )
  $g.FillPolygon((Brush (C 96 "4a443b")), $shade)

  # the collar and its mouth
  $g.FillRectangle((Brush (C 255 "978e80")), 0, 0, $w, $collar)
  $g.FillRectangle((Brush (C 70 "ffffff")), 0, 0, $w, 4)
  $g.FillRectangle((Brush (C 110 "443e36")), 0, $collar - 5, $w, 5)
  $mw = [int]($w * 0.62); $mh = [int]($collar * 0.5)
  $mx = [int](($w - $mw) / 2); $my = [int]($collar * 0.22)
  $g.FillRectangle((Brush (C 255 "241f1a")), $mx, $my, $mw, $mh)
  $g.FillRectangle((Brush (C 60 "ffffff")), $mx, $my + $mh - 2, $mw, 2)
  $g.Dispose()
  $b
}

(New-Masonry 128 $false).Save((Join-Path $out "masonry.png"), [System.Drawing.Imaging.ImageFormat]::Png)
(New-Masonry 128 $true ).Save((Join-Path $out "sigil_block.png"), [System.Drawing.Imaging.ImageFormat]::Png)
(New-Conduit 160 227  ).Save((Join-Path $out "conduit.png"), [System.Drawing.Imaging.ImageFormat]::Png)
Get-ChildItem (Join-Path $out "*.png") | Where-Object { $_.Name -match "masonry|sigil_block|conduit" } |
  Select-Object Name, Length
