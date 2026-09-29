package theme

const (
	YellowHex = "#FEC824"
	OchreHex  = "#A38319"
	OrangeHex = "#FF8C28"
	RedHex    = "#EF4444"
	GreenHex  = "#22C55E"
	WhiteHex  = "#F5F5F5"
	GreyHex   = "#9CA3AF"
	DimHex    = "#6B7280"
	TrackHex  = "#2A2A2A"
	BlueHex   = "#60A5FA"
	VioletHex = "#A78BFA"
)

// ProductHex is the colour of a product in the weekly breakdown, the same in
// every view.
func ProductHex(key string) string {
	switch key {
	case "claude_code":
		return YellowHex
	case "chat":
		return BlueHex
	case "cowork":
		return VioletHex
	}
	return DimHex
}
