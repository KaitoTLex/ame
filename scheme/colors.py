#!/usr/bin/env python3

import sys
import yaml


def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple"""
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


def print_color_block(hex_color):
    """Print a colored block using ANSI escape codes"""
    try:
        r, g, b = hex_to_rgb(hex_color)
        # Background color block
        bg_block = f"\033[48;2;{r};{g};{b}m  \033[0m"
        # Foreground color (white or black depending on background brightness)
        brightness = (r * 299 + g * 587 + b * 114) / 1000
        text_color = 30 if brightness > 128 else 37  # Black or white text
        fg_block = f"\033[{text_color}m{hex_color}\033[0m"
        return f"{bg_block} {fg_block}"
    except:
        return hex_color


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 base16_colors.py <colorscheme.yaml>")
        sys.exit(1)

    try:
        with open(sys.argv[1], "r") as file:
            data = yaml.safe_load(file)
    except FileNotFoundError:
        print(f"Error: File '{sys.argv[1]}' not found")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        sys.exit(1)

    # Print scheme info
    print(f"Scheme: {data.get('name', 'Unknown')}")
    print(f"Author: {data.get('author', 'Unknown')}")
    print(f"Variant: {data.get('variant', 'Unknown')}")
    print("-" * 40)

    # Print colors
    palette = data.get("palette", {})
    for key, hex_color in palette.items():
        color_name = key.replace("base", "Base ")
        print(f"{color_name:<8} {print_color_block(hex_color)}")


if __name__ == "__main__":
    main()
