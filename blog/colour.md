The color scheme is defined in the CSS section. Here are the main parts that control the colors:

## **🎨 Primary Color Scheme:**

```css
/* Main gradient background */
body {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

/* Card/slide backgrounds */
.slide {
    background: white;
}
```

## **🔵 Key Color Variables:**

**Primary Blues/Purples:**
- `#667eea` - Light blue (primary brand color)
- `#764ba2` - Purple (secondary brand color)
- Used in: gradients, buttons, security badges, workflow steps

**Neutral Colors:**
- `#2c3e50` - Dark blue-gray (headings, text)
- `#34495e` - Medium blue-gray (subheadings)
- `#2980b9` - Bright blue (H3 headings)

**Accent Colors:**
- `#3498db` - Bright blue (borders, underlines)
- `#27ae60` - Green (success, checkmarks)
- `#e74c3c` - Red (warnings, tier badge)
- `#f39c12` - Orange (warning icons)

## **🎯 Main Elements Using Colors:**

```css
/* Buttons and interactive elements */
.nav-btn, .workflow-step, .security-badge, .arch-component {
    background: linear-gradient(135deg, #667eea, #764ba2);
}

/* Success/positive elements */
.comparison-card.new {
    border-left-color: #27ae60; /* Green */
}

/* Warning/negative elements */
.comparison-card {
    border-left-color: #e74c3c; /* Red */
}
```

If you want to change the color scheme, you'd modify these hex color codes. For example, to make it more corporate blue, you could change `#667eea` and `#764ba2` to different blue shades throughout the CSS.