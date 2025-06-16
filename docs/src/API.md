---
layout: default
title: API
nav_order: 4
has_children: true
has_toc: false
---

# API

## Table of Contents

### Prediction & Thresholding
  - **[PredictCellCycle](https://plaisier-lab.github.io/ccafv2_Rv2/src/PredictCellCycle.html)**  
    Run the ccAFv2 classifier and assign cell cycle states.
  - **[AdjustCellCycleThreshold](https://plaisier-lab.github.io/ccafv2_Rv2/src/AdjustCellCycleThreshold.html)**  
    Re-assign states based on a new prediction confidence threshold.
    
### Data Preparation For Cell Cycle Regression 
  -  **[PrepareForCellCycleRegression](https://plaisier-lab.github.io/ccafv2_Rv2/src/PrepareForCellCycleRegression.html)**  
    Compute module scores from marker gene sets for regression.  

### Visualization
  - **[DimPlot.ccAFv2](https://plaisier-lab.github.io/ccafv2_Rv2/src/DimPlotccAFv2.html)**  
    Plot predicted cell cycle states on a UMAP or PCA.
  - **[SpatialDimPlot.ccAFv2](https://plaisier-lab.github.io/ccafv2_Rv2/src/SpatialDimPlotccAFv2.html)**  
    Visualize predicted states in spatial transcriptomics data.  
  - **[ThresholdPlot](https://plaisier-lab.github.io/ccafv2_Rv2/src/ThresholdPlot.html)**  
    Visualize how prediction thresholds affect state assignment.  

