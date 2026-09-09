#!/usr/bin/env python3
"""Genera los iconos de Android e iOS a partir de `CompassTorch.svg`.

El SVG es el original del icono: una brújula cuya aguja es una linterna, sobre
fondo transparente. Aquí se rasteriza, se centra sobre el fondo oscuro de la
aplicación y se exporta a todos los tamaños que piden las dos plataformas.

Uso: python3 tool/generate_app_icons.py   (necesita Pillow y CairoSVG)
"""

from __future__ import annotations

import json
from io import BytesIO
from math import ceil
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "CompassTorch.svg"

# Fondo del icono: un degradado oscuro y neutro, para no competir con los
# grises y el naranja del dibujo.
BG_TOP = (0x20, 0x21, 0x23)
BG_BOTTOM = (0x0A, 0x0B, 0x0C)

SS = 2  # supermuestreo: se compone al doble y se reduce con Lanczos.

# Parte del lado del icono que ocupa el cuadrado del dibujo. Ese cuadrado lleva
# margen transparente a los lados y abajo —lo que sobra al centrarlo en la
# brújula—, así que puede estirarse más que el recorte ajustado al contenido.
FULL_BLEED = 0.9

# El icono adaptativo dibuja sobre 108dp pero solo garantiza los 66dp
# centrales: el resto se lo puede comer la máscara del lanzador.
ADAPTIVE = 66 / 108 * 0.98

# Por encima de este brillo el dibujo es aro, marcas, letras o aguja; por
# debajo, la esfera oscura. Sirve para sacar la silueta del icono monocromo.
MONOCHROME_THRESHOLD = 60


def artwork(px: int) -> Image.Image:
    """El SVG rasterizado a un cuadrado de [px] de lado, centrado en la brújula.

    El dibujo no está centrado en su propia caja: la llama de la linterna
    sobresale bastante por arriba, así que recortar al contenido y centrar esa
    caja deja el círculo de la brújula desplazado hacia abajo. El SVG sí está
    compuesto con el círculo en el centro de su lienzo, de modo que se recorta
    un cuadrado centrado en ese punto, con el lado justo para que no se pierda
    nada del dibujo.
    """
    canvas = px * 2
    raw = cairosvg.svg2png(url=str(SVG), output_width=canvas, output_height=canvas)
    image = Image.open(BytesIO(raw)).convert("RGBA")

    left, top, right, bottom = image.getbbox()
    centre = canvas // 2
    half = ceil(
        max(centre - left, right - centre, centre - top, bottom - centre)
    )
    square = Image.new("RGBA", (2 * half, 2 * half), (0, 0, 0, 0))
    square.alpha_composite(image, (half - centre, half - centre))
    return square.resize((px, px), Image.LANCZOS)


def silhouette(image: Image.Image) -> Image.Image:
    """Silueta blanca del dibujo, sin la esfera oscura.

    Android 13 tiñe esta capa con el color del tema, así que una silueta que
    incluyera el disco entero saldría como un círculo macizo.
    """
    grey = image.convert("L")
    alpha = image.getchannel("A")
    mask = Image.eval(grey, lambda v: 255 if v >= MONOCHROME_THRESHOLD else 0)
    mask = Image.composite(mask, Image.new("L", image.size, 0), alpha)
    white = Image.new("RGBA", image.size, (255, 255, 255, 0))
    white.putalpha(mask)
    return white


def _background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), BG_BOTTOM + (255,))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = (y / max(size - 1, 1)) ** 0.85
        color = tuple(
            round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)
        )
        draw.line([(0, y), (size, y)], fill=color + (255,))
    return image


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


def render(
    size: int,
    shape: str = "square",
    background: bool = True,
    content: float = FULL_BLEED,
    monochrome: bool = False,
) -> Image.Image:
    """Compone el icono al tamaño pedido."""
    big = size * SS
    image = (
        _background(big)
        if background
        else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    )

    art = artwork(round(big * content))
    if monochrome:
        art = silhouette(art)
    image.alpha_composite(
        art, ((big - art.width) // 2, (big - art.height) // 2)
    )

    mask = _mask(big, shape)
    if mask is not None:
        image.putalpha(
            Image.composite(
                image.getchannel("A"), Image.new("L", (big, big), 0), mask
            )
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
        adaptive = round(108 * factor)
        save(
            render(adaptive, background=False, content=ADAPTIVE),
            res / f"mipmap-{name}/ic_launcher_foreground.png",
        )
        save(
            render(
                adaptive, background=False, content=ADAPTIVE, monochrome=True
            ),
            res / f"mipmap-{name}/ic_launcher_monochrome.png",
        )


def generate_ios() -> None:
    print("iOS:")
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())
    seen = set()
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename or filename in seen:
            continue
        seen.add(filename)
        base = float(entry["size"].split("x")[0])
        pixels = round(base * float(entry["scale"].rstrip("x")))
        # iOS no admite transparencia y aplica su propia máscara.
        save(render(pixels), appicon / filename, opaque=True)


if __name__ == "__main__":
    generate_android()
    generate_ios()
