class_name UiPalette
extends RefCounted
## The colour tokens of the mobile redesign (story 019b, production/design/ui-refonte/). The theme
## [code]main_theme.tres[/code] cannot read a constant, so it repeats these values, and
## [code]main_theme_contrast_test.gd[/code] checks that the two agree. Code that draws its own
## shapes (companions, rings, the panel handle) reads them from here.
##
## Every text pair reaches 4.5:1 (WCAG 2.1 AA) and every non-text signal 3:1; the ratios are in the
## comments. Display settings, not gameplay values.
##
## Usage:
## [codeblock]
## draw_rect(Rect2(Vector2.ZERO, size), UiPalette.PANEL)
## label.add_theme_color_override(&"font_color", UiPalette.TEXT_MUTED)
## [/codeblock]

## Page background and header.
const BACKGROUND: Color = Color("#0F1220")
## Management panel, tab bar, game zone.
const PANEL: Color = Color("#171B33")
## A row of a list.
const ROW: Color = Color("#1F2445")
## A row under the pointer or chosen.
const ROW_HOVER: Color = Color("#262B4F")
## Neutral button, and a button that cannot be paid.
const BUTTON: Color = Color("#2A2F52")
const BUTTON_HOVER: Color = Color("#343A63")

## Action that can be paid, chosen segment, gold. [constant ON_YELLOW] on it: 11.49:1.
const YELLOW: Color = Color("#FFC247")
const YELLOW_HOVER: Color = Color("#E6AE3F")
const YELLOW_PRESSED: Color = Color("#CC9B38")
## Edge of a payable button: its state is told by a border too.
const YELLOW_EDGE: Color = Color("#FFE08A")
const ON_YELLOW: Color = Color("#1A1300")

## Level of a companion, Rare rarity: 7.76:1 on a row.
const BLUE: Color = Color("#7CC0FF")
## Secondary text: 7.05:1 on a row.
const TEXT_MUTED: Color = Color("#A9B1CC")
## Text of a DISABLED control only: 5.04:1 on [constant BUTTON]. An enabled control keeps a light
## text.
const TEXT_DISABLED: Color = Color("#9AA1BC")
## Light text that is not white: 10.18:1 on a row.
const TEXT_SOFT: Color = Color("#D0D4E4")

## Awakening: white on it 5.90:1.
const VIOLET: Color = Color("#6E40E8")
const VIOLET_HOVER: Color = Color("#5F36CC")
const VIOLET_PRESSED: Color = Color("#5230B0")
const VIOLET_EDGE: Color = Color("#B49CFF")
## Equip and switches that are on: white on it 5.39:1.
const GREEN: Color = Color("#167A42")
const GREEN_HOVER: Color = Color("#126635")
const GREEN_PRESSED: Color = Color("#0F552C")
const GREEN_EDGE: Color = Color("#7FE0A6")
## Boss and notification dot: white on it 6.54:1.
const RED: Color = Color("#B3261E")
const RED_HOVER: Color = Color("#961F19")
const RED_PRESSED: Color = Color("#7D1A15")

## Hit points gauge and its empty part: white text on the fill 5.60:1, with a black outline; fill
## on the empty part 3.19:1.
const HP_RED: Color = Color("#C42B37")
const HP_BACK: Color = Color("#2E0C10")
## Common rarity: 9.03:1 on a row.
const COMMON: Color = Color("#C3C8DC")
## A talent that is owned: white on it 14.36:1, yellow edge 8.93:1.
const OWNED_BG: Color = Color("#2E2A1A")
