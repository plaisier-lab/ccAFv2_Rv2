##' Predict Cell Cycle
#'
#' This function predicts the cell cycle state for each cell in the object
#' using the ccAFv2 cell cycle classifier. The possible cell cycle states that
#' ccAFv2 can predict are: Neural G0, G1, G1/other, Late G1, S, S/G2, G2/M,
#' and M/Early G1.
#'
#' The ccAFv2 predicts the cell cycle state for each cell in the object by
#' selecting the cell cycle state for each cell with the maximum cell cycle
#' state probability. If the cell cycle state probability for a cell does not
#' meet the probability threshold, the cell will receive an 'Unknown' cell cycle
#' state prediction. ccAFv2 cell cycle state predictions and probabilities for
#' each cell in the object will be stored in the object .obs after classification.
#'
#' @param seurat0: a seurat object must be supplied to classify, no default
#' @param threshold: the value used to threchold the likelihoods, default is 0.5
#' @param include_g0: whether to provide Neural G0 calls, or collapse G1, Late G1 and Neural G0 into G0/G1 (FALSE collapses, TRUE provides Neural G0 calls)
#' @param do_sctransform: whether to do SCTransform before classifying, default is TRUE
#' @param assay: which seurat_obj assay to use for classification, helpful if data is prenormalized, default is 'SCT'
#' @param species: from which species did the samples originate, either 'human' or 'mouse', defaults to 'human'
#' @param gene_id: what type of gene ID is used, either 'ensembl' or 'symbol', defaults to 'ensembl'
#' @param spatial: whether the data is spatial, defaults to FALSE
#' @return Seurat object with ccAFv2 calls and probabilities for each cell cycle state
#' @export
PredictCellCycle = function(seurat_obj, threshold=0.5, include_g0 = FALSE, do_sctransform=TRUE, assay='SCT', species='human', gene_id='ensembl', spatial = FALSE) {
    cat('Running ccAFv2:\n')
    # Make a copy of object
    seurat1 = seurat_obj
  
    # Load model and marker genes
    classes = read.csv(system.file('extdata', 'ccAFv2_classes.txt', package='ccAFv2'), header=FALSE)$V1
    marker_genes = read.csv(system.file('extdata', 'ccAFv2_genes.csv', package='ccAFv2'), header=TRUE, row.names=1)[,paste0(species,'_',gene_id)]

    
    # Run SCTransform on data being sure to include the marker_genes
    if(assay=='SCT' & do_sctransform) {
        cat('  Redoing SCTransform to ensure maximum overlap with classifier genes...\n')
        if(!spatial) {
            seurat1 = SCTransform(seurat1, return.only.var.genes=FALSE, verbose=FALSE)
        } else {
            seurat1 = SCTransform(seurat1, assay = 'Spatial', return.only.var.genes=FALSE, verbose=FALSE)
        }
    }

    # Subset data marker genes to marker genes included in classification
    common_genes = intersect(row.names(seurat1),marker_genes)

    # Find missing genes and assign 0s to each cell
    cat(paste0('  Total possible marker genes for this classifier: ', length(marker_genes),'\n'))
    if(assay=='SCT') {
        input_mat = seurat1@assays$SCT@scale.data[common_genes,]
    } else {
        input_mat = seurat1@assays$RNA@data[common_genes,]
    }

    missing_genes = setdiff(marker_genes, rownames(input_mat))
    
    cat(paste0('    Marker genes present in this dataset: ', nrow(input_mat),'\n'))
    cat(paste0('    Missing marker genes in this dataset: ', length(missing_genes),'\n'))
    
    if(nrow(input_mat)<=689) {
        warning("Overlap below 80%: try setting 'do_sctransform' parameter to TRUE.")
    }
    
    input_mat_scaled = t(scale(t(as.matrix(input_mat))))

    # create the input and output arrays (oup_preds) here with 
    # names and dimensions of marker_genes x samples (cols in seurat object 1)
    nscaled_data = matrix(min(input_mat_scaled,na.rm=T),
                          nrow=length(marker_genes), ncol=ncol(seurat1), 
                          dimnames = list(marker_genes, colnames(seurat1)))

    # add in the nromalized expression data from the seurat data set 
    nscaled_data[common_genes, ] = input_mat_scaled[common_genes, ]           
    nscaled_data[!is.finite(nscaled_data)] = 0
    
    cat(paste0('  Predicting cell cycle state probabilities...\n'))

    # apply classifier to normalized and scaled data.  Then give the resulting output (oup) row names
    oup_preds = apply(nscaled_data, 2, ccAFv2_classifier)
    rownames(oup_preds) = classes   
   
    # organize the predictions into a dataframe and return the foudn cell cycle states
    # We need the dataframe with rows as samples hence the transpose here
    df1 = data.frame(t(oup_preds))
    cat(paste0('  Choosing cell cycle state...\n'))
    if(include_g0) {
        
      CellCycleState = data.frame(factor(rownames(oup_preds)[apply(oup_preds,2,which.max)], levels=c('Neural G0','G1','Late G1','S','S/G2','G2/M','M/Early G1','Unknown')), row.names = colnames(oup_preds))

    } else {
        
        max_state = rownames(oup_preds)[apply(oup_preds,2,which.max)]
        max_state[max_state=='Neural G0'] = 'G0/G1'
        max_state[max_state=='G1'] = 'G0/G1'
        max_state[max_state=='Late G1'] = 'G0/G1'
        CellCycleState = data.frame(factor(max_state, levels=c('G0/G1','S','S/G2','G2/M','M/Early G1','Unknown')), row.names = colnames(oup_preds))
    
    }
    
    colnames(CellCycleState) = 'ccAFv2'
    df1[,'ccAFv2'] = CellCycleState$ccAFv2
    df1[which(apply(oup_preds,2,max)<threshold),'ccAFv2'] = 'Unknown'
    
    cat('  Adding probabilities and predictions to metadata\n')
    seurat_obj = AddMetaData(object = seurat_obj, metadata = df1)
    
    cat('Done\n')
    return(seurat_obj)
}

#' Adjust Cell Cycle Threshold
#'
#' This function allows users to adjust the threshold applied to ccAFv2 predictions.
#' The user can utilize the ThresholdPlot to see the effect of increasing threshold
#' values have on the number of 'Unknown' cell calls.
#'
#' @param seurat0: a seurat object must be supplied to classify, no default
#' @param threshold: the value used to threchold the likelihoods, default is 0.5
#' @param include_g0: whether to provide Neural G0 calls, or collapse G1, Late G1 and Neural G0 into G0/G1 (FALSE collapses, TRUE provides Neural G0 calls)
#' @return Seurat object with ccAFv2 calls and probabilities for each cell cycle state
#' @export
AdjustCellCycleThreshold = function(seurat_obj, threshold=0.5, include_g0=FALSE) {
    cat('Adjusting threshold:\n')
    classes = read.csv(system.file('extdata', 'ccAFv2_classes.txt', package='ccAFv2'), header=FALSE)$V1
    predictions1 = seurat_obj@meta.data[,make.names(classes)]
    colnames(predictions1) = classes
    df1 = data.frame(predictions1)
    if(include_g0) {
        CellCycleState = data.frame(factor(colnames(predictions1)[apply(predictions1,1,which.max)], levels=c('Neural G0','G1','Late G1','S','S/G2','G2/M','M/Early G1','Unknown')), row.names = rownames(predictions1))
    } else {
        max_state = colnames(predictions1)[apply(predictions1,1,which.max)]
        max_state[max_state=='Neural G0'] = 'G0/G1'
        max_state[max_state=='G1'] = 'G0/G1'
        max_state[max_state=='Late G1'] = 'G0/G1'
        CellCycleState = data.frame(factor(max_state, levels=c('G0/G1','S','S/G2','G2/M','M/Early G1','Unknown')), row.names = rownames(predictions1))
    }
    colnames(CellCycleState) = 'ccAFv2'
    df1[,'ccAFv2'] = CellCycleState$ccAFv2
    df1[which(apply(predictions1,1,max)<threshold),'ccAFv2'] = 'Unknown'
    seurat_obj$ccAFv2 = df1[,'ccAFv2']
    cat('Done\n')
    return(seurat_obj)
}

#' Prepare expression module scores for regressing out the cell cycle
#'
#' This function computes moduel scores for each cell cycle state
#'
#' @param seurat0: a seurat object must be supplied to classify, no default
#' @param assay: which seurat_obj assay to use for classification, helpful if data is prenormalized, default is 'SCT'
#' @param species: from which species did the samples originate, either 'human' or 'mouse', defaults to 'human'
#' @param gene_id: what type of gene ID is used, either 'ensembl' or 'symbol', defaults to 'ensembl'
#' @param spatial: whether the data is spatial, defaults to FALSE
#' @return Seurat object with cell cycle state module scores appended to meta.data
#' @export
PrepareForCellCycleRegression = function(seurat_obj, assay='SCT', species='human', gene_id='ensembl') {
    marker_genes = read.csv(system.file('extdata', 'ccAFv2_genes.csv', package='ccAFv2'), header=TRUE, row.names=1)

    cluster_genes = list()
    for (cluster in c('Late.G1','S','S.G2','G2.M','M.Early.G1')) {
        cluster_genes[[cluster]] = marker_genes[marker_genes[,cluster]==1,paste(species,gene_id,sep='_')]
    }
    seurat_obj = AddModuleScore(seurat_obj, features = cluster_genes, name = paste0(c('Late.G1','S','S.G2','G2.M','M.Early.G1'), '_exprs'))
    return(seurat_obj)
}

#' DimPlot of ccAFv2 predictions with standard colors
#'
#' This function plots the cell cycle onto a DimPlot for single cell or nuclei data.
#'
#' @param Seurat object that should have ccAFv2 cell cycle states predicted.
#' @return A DimPlot object that can be plotted.
#' @export
DimPlot.ccAFv2 = function(seurat_obj, ...) {
    dp1 = DimPlot(seurat_obj, group.by='ccAFv2', cols = c('G1' = '#f37f73', 'G2/M' = '#3db270', 'Late G1' = '#1fb1a9','M/Early G1' = '#6d90ca', 'Neural G0' = '#d9a428', 'S' = '#8571b2', 'S/G2' = '#db7092', 'G0/G1' = '#FF6600', 'Unknown' = '#cccccc'), ...)
    return(dp1)
}

#' SpatialDimPlot of ccAFv2 predictions with standard colors
#'
#' This function plots the cell cycle onto a DimPlot for spatial data.
#'
#' @param Seurat object with ccAFv2 cell cycle states predicted.
#' @return A DimPlot object that can be plotted.
#' @export
SpatialDimPlot.ccAFv2 = function(seurat_obj, ...) {
    dp1 = SpatialDimPlot(seurat_obj, group.by='ccAFv2', cols = c('G1' = '#f37f73', 'G2/M' = '#3db270', 'Late G1' = '#1fb1a9','M/Early G1' = '#6d90ca', ' Neural G0' = '#d9a428', 'S' = '#8571b2', 'S/G2' = '#db7092', 'G0/G1' = '#FF6600'), ...)
    return(dp1)
}

#' ThresholdPlot of ccAFv2 predictions with a range of thresholds using standard colors
#'
#' This function plots the distribution of cell cycle predictions for a range of thresholds
#' as a barplot colorized using the standard cell cycle state colors.
#'
#' @param Seurat object with ccAFv2 cell cycle states predicited.
#' @return A ggplot object that can be plotted.
#' @export
ThresholdPlot = function(seurat_obj, ...) {
    predictions1 = seurat_obj@meta.data[,c('Neural.G0','G1','Late.G1','S','S.G2','G2.M','M.Early.G1')]
    CellCycleState = data.frame(factor(colnames(predictions1)[apply(predictions1,1,which.max)], levels=c('Neural.G0','G1','Late.G1','S','S.G2','G2.M','M.Early.G1','Unknown')), row.names = rownames(predictions1))
    colnames(CellCycleState) = 'ccAFv2'
    dfall = data.frame(table(CellCycleState)/nrow(CellCycleState))
    dfall[,'Threshold'] = 0
    for(threshold in c(0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9)) {
        CellCycleState = data.frame(factor(colnames(predictions1)[apply(predictions1,1,which.max)], levels=c('Neural.G0','G1','Late.G1','S','S.G2','G2.M','M.Early.G1','Unknown')), row.names = rownames(predictions1))
        colnames(CellCycleState) = 'ccAFv2'
        CellCycleState[which(apply(predictions1,1,max)<threshold),'ccAFv2'] = 'Unknown'
        df1 = data.frame(table(CellCycleState)/nrow(CellCycleState))
        df1[,'Threshold'] = as.character(threshold)
        dfall = rbind(dfall, df1)
    }
    tp1 = ggplot2::ggplot(dfall) + ggplot2::geom_bar(ggplot2::aes(x = Threshold, y = Freq, fill = ccAFv2), position = "stack", stat = "identity") + ggplot2::scale_fill_manual(values = c('G1' = '#f37f73', 'G2.M' = '#3db270', 'Late.G1' = '#1fb1a9', 'M.Early.G1' = '#6d90ca', 'Neural.G0' = '#d9a428', 'S' = '#8571b2', 'S.G2' = '#db7092', 'Unknown' = '#CCCCCC', 'G0/G1' = '#E34234')) + ggplot2::theme_minimal()
    return(tp1)
}


#' ccAFv2 classifier function
#' 
#' This function calls the C code C_ccAFv2.c to run the neural network classifier. 
#' ccAFv2_classifier returns a 1 x 7 double precision vector of predictions 
#' 
#' @param  norm_expVec a double precision 1 x 861 vector of normalized gene expression values
#' @return  ccAFv2_classifier returns a 1 x 7 double precision vector of class probabilites
#'
#' @export
ccAFv2_classifier <- function(norm_expVec) {
  .Call("C_ccAFv2", norm_expVec)
}
