export function Icon({ name, size = 22 }: { name: string; size?: number }) {
  const paths: Record<string, string> = {
    home: "m3 10 9-7 9 7v10H3V10Zm6 10v-7h6v7",
    expenses: "M5 3h14v18l-3-2-4 2-4-2-3 2V3Zm3 5h8M8 12h8M8 16h4",
    group:
      "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-3.87M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8m8-7a4 4 0 0 1 0 8",
    bell: "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4",
    settings:
      "M12 3v3m0 12v3M3 12h3m12 0h3M6 6l2 2m8 8 2 2M6 18l2-2m8-8 2-2M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8",
    plus: "M12 5v14M5 12h14",
    arrow: "M7 17 17 7M7 7h10v10",
    wallet: "M3 7h18v13H3V7Zm0 0V4h15v3m-2 6h5v3h-5v-3",
    moon: "M21 13A9 9 0 0 1 11 3a9 9 0 1 0 10 10",
    logout: "M9 3H3v18h6m5-14 5 5-5 5m-6-5h13",
    check: "m5 12 4 4L19 6",
    refresh: "M20 7v5h-5M4 17v-5h5M6 6a8 8 0 0 1 14 6M4 12a8 8 0 0 0 14 6",
  };
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[name] ?? paths.wallet} />
    </svg>
  );
}
export function Brand() {
  return (
    <div className="brand">
      <span className="brand-icon">
        <Icon name="home" size={28} />
      </span>
      <span>
        مسكن<small>MASKAN</small>
      </span>
    </div>
  );
}

export function Avatar({
  initials,
  name,
  color,
}: {
  initials?: string | null;
  name: string;
  color?: string | null;
}) {
  const validColor = color && /^#[0-9a-f]{6}$/i.test(color) ? color : undefined;
  const channels = validColor
    ? [1, 3, 5].map((index) => {
        const channel = parseInt(validColor.slice(index, index + 2), 16) / 255;
        return channel <= 0.04045
          ? channel / 12.92
          : Math.pow((channel + 0.055) / 1.055, 2.4);
      })
    : null;
  const luminance = channels
    ? channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    : 0;
  return (
    <span
      className="avatar"
      style={
        validColor
          ? {
              backgroundColor: validColor,
              color: luminance > 0.179 ? "#000" : "#fff",
            }
          : undefined
      }
    >
      {initials || name.slice(0, 2)}
    </span>
  );
}
