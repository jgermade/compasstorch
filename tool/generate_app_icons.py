#!/usr/bin/env python3
"""Genera los iconos de Android e iOS a partir de la rosa de los vientos.

El dibujo reproduce el dial de `lib/widgets/compass_dial.dart` con los colores
de `lib/theme.dart`: la aguja ámbar de la linterna, la marca cian del modo faro
y el fondo oscuro de la aplicación.

Uso: python3 tool/generate_app_icons.py   (necesita Pillow)
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# Paleta: los mismos valores que AppColors en lib/theme.dart.
TORCH = (0xFF, 0xB0, 0x20)
BEACON = (0x00, 0xB8, 0xD4)
BG_TOP = (0x16, 0x20, 0x2B)
BG_BOTTOM = (0x05, 0x07, 0x0A)
OUTLINE = (0x2A, 0x36, 0x44)
TICK = (0x8F, 0xA0, 0xB2)
SOUTH = (0x3C, 0x4B, 0x5B)
HUB = (0x13, 0x1A, 0x22)

SS = 4  # supermuestreo: se dibuja a 4x y se reduce con Lanczos.

# Fracciones del lado del icono.
R_DIAL = 0.375
NEEDLE_TILT = -18.0  # grados; la aguja no coincide con la marca fija.

# El icono adaptativo dibuja sobre 108dp pero solo se ven los 66dp centrales:
# se encoge el dial para que la marca del rumbo no quede recortada.
ADAPTIVE_SCALE = 0.72


def _rotate(point, degrees):
    angle = math.radians(degrees)
    x, y = point
    return (
        x * math.cos(angle) - y * math.sin(angle),
        x * math.sin(angle) + y * math.cos(angle),
    )


def _draw_background(size: int) -> Image.Image:
    """Degradado vertical con un halo ámbar tenue detrás de la aguja."""
    image = Image.new("RGBA", (size, size), BG_BOTTOM + (255,))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / max(size - 1, 1)
        # Curva suave: el fondo se apaga rápido hacia abajo.
        t = t ** 0.85
        color = tuple(
            round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)
        )
        draw.line([(0, y), (size, y)], fill=color + (255,))

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    center = size / 2
    steps = 90
    for step in range(steps, 0, -1):
        radius = size * 0.46 * step / steps
        alpha = round(26 * (1 - step / steps) ** 2)
        glow_draw.ellipse(
            [center - radius, center - radius, center + radius, center + radius],
            fill=TORCH + (alpha,),
        )
    return Image.alpha_composite(image, glow)


def _draw_dial(size: int, scale: float) -> Image.Image:
    """La rosa de los vientos sobre fondo transparente."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    center = size / 2
    radius = size * R_DIAL * scale

    def at(dx, dy):
        return (center + dx, center + dy)

    # Aro exterior.
    ring = radius * 0.055
    draw.ellipse(
        [center - radius, center - radius, center + radius, center + radius],
        outline=OUTLINE + (255,),
        width=max(1, round(ring)),
    )

    # Marcas: largas cada 45°, medias cada 15°.
    outer = radius - ring * 1.6
    for degrees in range(0, 360, 15):
        major = degrees % 45 == 0
        length = radius * (0.20 if major else 0.11)
        width = max(1, round(radius * (0.048 if major else 0.026)))
        alpha = 255 if major else 130
        angle = math.radians(degrees - 90)
        direction = (math.cos(angle), math.sin(angle))
        draw.line(
            [
                at(direction[0] * outer, direction[1] * outer),
                at(
                    direction[0] * (outer - length),
                    direction[1] * (outer - length),
                ),
            ],
            fill=TICK + (alpha,),
            width=width,
        )

    # Aguja: punta ámbar al norte, cola apagada al sur.
    tip = radius * 0.70
    half = radius * 0.135
    north = [(0, -tip), (half, 0), (0, radius * 0.10), (-half, 0)]
    south = [(0, tip), (half * 0.92, 0), (0, -radius * 0.10), (-half * 0.92, 0)]
    draw.polygon(
        [at(*_rotate(p, NEEDLE_TILT)) for p in north], fill=TORCH + (255,)
    )
    draw.polygon(
        [at(*_rotate(p, NEEDLE_TILT)) for p in south], fill=SOUTH + (255,)
    )

    # Cubo central.
    hub = radius * 0.12
    draw.ellipse(
        [center - hub, center - hub, center + hub, center + hub],
        fill=HUB + (255,),
        outline=OUTLINE + (255,),
        width=max(1, round(radius * 0.022)),
    )

    # Marca fija del rumbo, en el cian del modo faro.
    marker_tip = radius - ring * 0.2
    marker_base = radius + radius * 0.16
    marker_half = radius * 0.115
    draw.polygon(
        [
            at(0, -marker_tip),
            at(-marker_half, -marker_base),
            at(marker_half, -marker_base),
        ],
        fill=BEACON + (255,),
    )
    return layer


def _mask(size: int, shape: str) -> Image.Image | None:
    if shape == "square":
        return None
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if shape == "circle":
        draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    else:  # rounded
        draw.rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=255
        )
    return mask


def render(size: int, shape: str = "square", background: bool = True,
           scale: float = 1.0) -> Image.Image:
    """Devuelve el icono ya reducido al tamaño pedido."""
    big = size * SS
    if background:
        image = _draw_background(big)
    else:
        image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    image = Image.alpha_composite(image, _draw_dial(big, scale))

    mask = _mask(big, shape)
    if mask is not None:
        image.putalpha(
            Image.composite(image.getchannel("A"), Image.new("L", (big, big), 0), mask)
        )
    return image.resize((size, size), Image.LANCZOS)


def save(image: Image.Image, path: Path, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        flat = Image.new("RGB", image.size, BG_BOTTOM)
        flat.paste(image, mask=image.getchannel("A"))
        flat.save(path)
    else:
        image.save(path)
    print(f"  {path.relative_to(ROOT)}")


# Densidades de Android: dp -> factor.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def generate_android() -> None:
    print("Android:")
    res = ROOT / "android/app/src/main/res"
    for name, factor in DENSITIES.items():
        legacy = round(48 * factor)
        save(render(legacy, shape="rounded"), res / f"mipmap-{name}/ic_launcher.png")
        save(
            render(legacy, shape="circle"),
            res / f"mipmap-{name}/ic_launcher_round.png",
        )
        # Icono adaptativo: lienzo de 108dp con el dibujo dentro de la zona
        # segura de 66dp (el sistema recorta los bordes y los anima).
        adaptive = round(108 * factor)
        save(
            render(adaptive, background=False, scale=ADAPTIVE_SCALE),
            res / f"mipmap-{name}/ic_launcher_foreground.png",
        )


def generate_ios() -> None:
    print("iOS:")
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        base = float(entry["size"].split("x")[0])
        pixels = round(base * float(entry["scale"].rstrip("x")))
        # iOS no admite transparencia y aplica su propia máscara.
        save(render(pixels), appicon / filename, opaque=True)


if __name__ == "__main__":
    generate_android()
    generate_ios()
