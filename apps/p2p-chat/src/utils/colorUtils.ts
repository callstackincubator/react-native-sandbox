// Color interpolation utility functions

export const hexToRgb = (hex: string) => {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  return result
    ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16),
      }
    : {r: 0, g: 0, b: 0}
}

export const rgbToHex = (r: number, g: number, b: number) => {
  return (
    '#' +
    ((1 << 24) + (Math.round(r) << 16) + (Math.round(g) << 8) + Math.round(b))
      .toString(16)
      .slice(1)
  )
}

export const interpolateColor = (
  color1: string,
  color2: string,
  factor: number
) => {
  const c1 = hexToRgb(color1)
  const c2 = hexToRgb(color2)

  const r = c1.r + factor * (c2.r - c1.r)
  const g = c1.g + factor * (c2.g - c1.g)
  const b = c1.b + factor * (c2.b - c1.b)

  return rgbToHex(r, g, b)
}
