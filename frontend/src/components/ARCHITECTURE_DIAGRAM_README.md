# Architecture Diagram Component

## Quick Start

### View the Diagram

```bash
cd frontend
npm install
npm run dev
```

Navigate to: `http://localhost:5173/architecture`

## Features

### 🎯 Interactive Process Flow
- **12 numbered steps** showing complete data flow
- Click any step to see detailed description
- Steps highlight related components on hover

### 🏗️ System Boundaries
- **On-Premise**: MySQL database infrastructure
- **AWS Cloud**: Complete VPC with subnets
- **User Zone**: Frontend and end users

### 🌐 VPC Architecture
- **Public Subnet** (10.0.1.0/24): API Gateway, WAF
- **Private Subnet 1** (10.0.2.0/24): Lambda functions
- **Private Subnet 2** (10.0.3.0/24): DMS, Batch jobs

### 🤖 Five AI Systems
1. Market Intelligence Hub (ARIMA, Prophet, LSTM)
2. Demand Insights Engine (XGBoost, K-Means)
3. Compliance Guardian (Isolation Forest, GBM)
4. Retail Copilot (LLM, NL to SQL)
5. Global Market Pulse (Geospatial, MCDA)

### ✨ Visual Effects
- Hover highlighting with glow animation
- Smooth transitions and transforms
- Responsive grid layout
- Print-optimized styles

## Process Flow Description

### User Request Flow (Steps 1-8)

1. **User Authentication**: Login via React → JWT token generated
2. **Dashboard Access**: Select AI system → Pass JWT token
3. **API Request**: HTTPS to API Gateway with auth
4. **Token Verification**: Lambda Authorizer checks JWT
5. **Analytics Query**: Lambda prepares Athena query
6. **Athena Execution**: Query Glue Catalog tables
7. **Data Retrieval**: Read Parquet from S3 prod
8. **Response to User**: Data visualized in dashboard

### Data Pipeline Flow (Steps 9-12)

9. **DMS Replication**: MySQL → S3 raw (CDC, 5min)
10. **Raw Processing**: Validate → Dedupe → Curated
11. **Curated to Prod**: Transform → Optimize → Prod
12. **Catalog Update**: Glue Crawler → Athena ready

## Component Structure

```
ArchitectureDiagram/
├── Process Flow Panel (top)
│   └── 12 clickable steps with descriptions
├── Main Diagram (center)
│   ├── On-Premise Boundary
│   ├── AWS Cloud Boundary
│   │   ├── VPC (10.0.0.0/16)
│   │   │   ├── Public Subnet
│   │   │   ├── Private Subnet 1
│   │   │   └── Private Subnet 2
│   │   └── Managed Services
│   └── User Zone
├── AI Systems Panel (bottom)
│   └── 5 system cards
└── Legend (bottom)
```

## Customization

### Add New Component

```tsx
<div 
  className="component new-service"
  onMouseEnter={() => setHoveredComponent('new-service')}
  onMouseLeave={() => setHoveredComponent(null)}
>
  <div className="component-icon">🆕</div>
  <div className="component-name">New Service</div>
  <div className="component-detail">Description</div>
  <div className="flow-number">13</div>
</div>
```

### Add New Process Step

```typescript
{
  id: 13,
  title: "New Step",
  description: "Step description",
  component: "new-service"
}
```

### Style New Component

```css
.new-service {
  background: linear-gradient(135deg, #color1 0%, #color2 100%);
  color: white;
}
```

## Color Scheme

### Boundaries
- 🟢 Green: On-Premise
- 🟠 Orange: AWS Cloud
- 🔵 Blue: User Zone

### Components
- MySQL: Green gradient
- API Gateway: Blue gradient
- Lambda: Orange gradient
- DMS: Purple gradient
- Batch: Cyan gradient
- S3: Red gradient
- Athena: Indigo gradient
- Glue: Deep purple gradient

## Responsive Breakpoints

- **Desktop**: Full layout with side-by-side components
- **Tablet** (< 1200px): Stacked managed services
- **Mobile** (< 768px): Single column layout

## Browser Support

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

## Performance

- CSS animations use `transform` (GPU-accelerated)
- Event delegation for efficient handling
- Minimal re-renders with React state
- Optimized for 60fps animations

## Accessibility

- Keyboard navigation support
- ARIA labels for screen readers
- High contrast colors
- Focus indicators

## Export Options

### Print to PDF
```javascript
window.print();
```

### Export as PNG
```javascript
import html2canvas from 'html2canvas';

const exportDiagram = async () => {
  const element = document.querySelector('.architecture-diagram');
  const canvas = await html2canvas(element);
  const link = document.createElement('a');
  link.download = 'architecture.png';
  link.href = canvas.toDataURL();
  link.click();
};
```

## Files

- `ArchitectureDiagram.tsx` - Main component (500+ lines)
- `ArchitectureDiagram.css` - Styling (800+ lines)
- `Architecture.tsx` - Page wrapper
- `ARCHITECTURE_DIAGRAM.md` - Full documentation

## Usage in Presentations

1. Open `/architecture` in browser
2. Press F11 for fullscreen
3. Click process steps to explain flow
4. Hover components to show relationships
5. Use for technical reviews and demos

## Future Enhancements

- [ ] Animated data flow visualization
- [ ] Zoom and pan controls
- [ ] Dark mode theme
- [ ] Real-time metrics overlay
- [ ] 3D architecture view
- [ ] Export to multiple formats
- [ ] Interactive tooltips
- [ ] Comparison views

## Related Documentation

- [Full Architecture Documentation](../../../ARCHITECTURE_DIAGRAM.md)
- [Frontend README](../../README.md)
- [System Design](.kiro/specs/ecommerce-ai-platform/design.md)

---

**Component**: Interactive React visualization  
**Lines of Code**: 1300+  
**Interactive Elements**: 30+  
**Process Steps**: 12  
**AI Systems**: 5  
**AWS Services**: 15+
