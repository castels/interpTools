#' Plot Performance Surfaces over a Discrete Mesh of Gap Structures
#' 
#' Subroutine of \code{multiSurface()}. Function to generate surface plots (using the \code{plotly} package) to visualize changes in the performance metrics of interest
#' as gap structure changes. 
#' \itemize{
#' \item The x-axis represents \code{p}, the \strong{proportion of missing data}.\cr 
#' \item The y-axis represents \code{g}, the \strong{gap width}.\cr
#' \item The z-axis represents \code{f(p,g)}, the \strong{value of the performance metric} of interest, according to some statistic.
#' }
#' 
#' @param d \code{numeric}; A vector to indicate datasets of interest
#' @param m \code{character}; A vector of interpolation methods of interest (maximum of 5)
#' @param metric \code{character}; An element describing the performance metric of interest
#' @param agObject \code{agObject}; An object containing the aggregated performance metrics (result of \code{agObject()})
#' @param layer_type \code{character}; How to layer the surfaces (by "method" or by "dataset") 
#' @param f \code{character}; The statistic of interest defining the surface \code{f(p,g)}. Possible choices are listed in \code{?aggregate_pf}.
#' @param highlight \code{character/numeric}; A single method (if \code{layer_type = "method"}) or dataset (if \code{layer_type = "dataset"}) to highlight.
#' @param highlight_color \code{character}; An HTML color of format \code{"#xxxxxx"} to apply to \code{highlight}
#' @param colors \code{character}; A vector of the desired color palette, with entries in HTML format (\code{"#xxxxxx"}) 
#' 
#' 

plotSurface <- function( d=1:length(agObject), 
                         m=names(agObject[[1]][[1]][[1]]), 
                         metric, 
                         agObject, 
                         layer_type = "method", 
                         f = "median", 
                         highlight = NULL, 
                         highlight_color = "#FF0000",
                         colors = c("#FF8633","#FFAF33","#FFD133","#FFEC33","#D7FF33","#96FF33")){ 
  
  ## LOGICAL CHECKS ############
  
  if(sum(duplicated(d) != 0)) stop(paste0("'d' contains redundant elements at position(s): ", paste0(c(1:length(d))[duplicated(d)], collapse = ", ") ))
  if(sum(duplicated(m) != 0)) stop(paste0("'m' contains redundant elements at position(s): ", paste0(c(1:length(m))[duplicated(m)], collapse = ", ") ))
  
  if(layer_type != "method" & layer_type != "dataset") stop("'layer_type' must equal either 'method' or 'dataset'.")
  
  
  if(!all(m %in%  names(agObject[[1]][[1]][[1]]))) stop("Method(s) '", paste0(m[!m %in% names(agObject[[1]][[1]][[1]])], collapse = ", ' "),"' not found. Possible choices are: '", paste0(names(agObject[[1]][[1]][[1]]), collapse = "', '"),"'.")
  if(!all(paste0("D",d) %in% names(agObject))) stop("Dataset(s) ", paste0(d[!paste0("D",d) %in% names(agObject)], collapse = ", ")," not found. Possible choices are: ", paste0(gsub("D", "",names(agObject)), collapse = ", "))
  if(!all(f %in% names(agObject[[1]][[1]][[1]][[1]]))) stop(paste0(c("f must be one of: '",paste0(names(agObject[[1]][[1]][[1]][[1]]), collapse = "', '"),"'."), collapse = ""))
  if(!metric %in% rownames(agObject[[1]][[1]][[1]][[1]])) stop(paste0("Metric '",metric,"' must be one of ", paste(rownames(agObject[[1]][[1]][[1]][[1]]),collapse = ", "),"."))
  
  if(length(metric) != 1) stop("'metric' must contain only a single character element.")
  if(length(f) != 1) stop("'f' must contain only a single character element.")
  if(length(layer_type) != 1) stop("'layer_type' must contain only a single character element.")
  if(length(highlight_color) != 1) stop("'highlight_color' must contain only a single character element.")
  
  if(class(agObject) != "aggregate_pf") stop("'agObject' object must be of class 'aggregate_pf'. Please use aggregate_pf().")
  
  if(!is.null(highlight)){
    if(length(highlight) != 1) stop("'highlight' must contain only a single character element.")
    if(layer_type == "method" & !highlight %in% m) stop(paste0(c("'highlight' must be an element of 'm'. Choose one of: '", paste0(m, collapse = "', '"),"'."), collapse = ""))
    if(layer_type == "dataset" & !highlight %in% d) stop(paste0(c("'highlight' must be an element of 'd'. Choose one of: '", paste0(d, collapse = "', '"),"'."), collapse = ""))
    if(layer_type == "dataset" & !is.numeric(highlight)) stop("If 'layer_type' = 'dataset', then 'highlight' must be of class 'numeric'.")
    if(layer_type == "method" & !is.character(highlight)) stop("If 'layer_type' = 'method', then 'highlight' must be of class 'character'.")
  }
  
  if(layer_type == "method" & length(m) > 1 & length(colors) < length(m)) warning(paste0("'colors' should contain at least ", length(m), " elements (each in HTML format: '#xxxxxx') if layering more than one method."))
  if(layer_type == "dataset" & length(d) > 1 & length(colors) < length(d)) warning(paste0("'colors' should contain at least ", length(d), " elements (each in HTML format: '#xxxxxx') if layering more than one dataset."))
  
  
  ##################
  
  
  P <- length(agObject[[1]])
  G <- length(agObject[[1]][[1]])
  prop_vec_names <- names(agObject[[1]])
  gap_vec_names <- names(agObject[[1]][[1]])
  
  
  D <- length(d)
  M <- length(m)
  C <- length(metric)
  
  
  z_list <- compileMatrix(agObject)[[f]]
  
  method_list_names <- names(z_list[[1]])[names(z_list[[1]]) %in% m]
  data_list_names = names(z_list[[1]][[1]])[d]
  
  if(layer_type == "method"){
    colorList <- colorRampPalette(colors)(M)
    
    colorListMatch <- colorList[1:M]
    names(colorListMatch) <- method_list_names
    
    if(!is.null(highlight)){
      colorListMatch[[highlight]] <- highlight_color
    }
    
    colorListMatch <- rep(colorListMatch, each = P*G)
    palette <- lapply(split(colorListMatch, names(colorListMatch)), unname)
    palette <- palette[method_list_names]
  }
  
  else if(layer_type == "dataset"){
    colorList <- colorRampPalette(colors)(D)
    
    colorListMatch <- colorList[1:D]
    names(colorListMatch) <- data_list_names
    
    if(!is.null(highlight)){
      colorListMatch[grepl(highlight, data_list_names)] <- highlight_color
    }
    
    colorListMatch <- rep(colorListMatch, each = P*G)
    palette <- lapply(split(colorListMatch, names(colorListMatch)), unname)
    palette <- palette[data_list_names]
  }
  
  
  ## Generating a list of surfaces 
  
  prop_vec <- as.numeric(gsub(x = names(agObject[[1]]),"p", "")) # proportions
  gap_vec <- as.numeric(gsub(x = names(agObject[[1]][[1]]),"g", "")) # gaps
  
  if(layer_type == "method"){
    
    plotList <- lapply(plotList <- vector(mode = 'list', C), function(x)
      x <- vector(mode = 'list', D))
    
    axx <- list(
      nticks = length(gap_vec),
      range = c(min(gap_vec),max(gap_vec)),
      title = "g"
    )
    
    axy <- list(
      nticks = length(prop_vec),
      range = c(min(prop_vec),max(prop_vec)),
      title = "p"
    )
    
    axz <- list(title = "f(p,g)",
                nticks = 4)
    
    for(s in 1:C){
      for(vd in 1:D){
        z <- numeric(M)
        txt_list <- list()
        
        if(M > 1){
          for(vm in 1:(M-1)){
            
            data <- z_list[[metric[s]]][[m[vm]]][[d[vd]]]
            txt <- array(dim = dim(data))
            
            for(p in 1:length(rownames(data))){
              for(g in 1:length(colnames(data))){
                txt[p,g] <- paste0("p = ", prop_vec[p]*100,"%<br />g =  ", gap_vec[g], "<br />f =  ", round(data[p,g],2))
              }
              
              txt_list[[vm]] <- txt
            }
            
            z[vm] <- paste("add_surface(x=gap_vec,y=prop_vec,z=z_list[['",metric[s],"']][['",m[vm],"']][[",d[vd],"]],
                            hovertemplate = t(txt_list[[",vm,"]]),
                           colorscale = list(seq(0,1,length.out=P*G), palette[['",m[vm],"']]),
                           name = method_list_names[grepl('",m[vm],"',method_list_names)], opacity = 1) %>% ",sep="")
          }
        }
        
        data <- z_list[[metric[s]]][[m[M]]][[d[vd]]]
        txt <- array(dim = dim(data))
        
        for(p in 1:length(rownames(data))){
          for(g in 1:length(colnames(data))){
            txt[p,g] <- paste0("p = ", prop_vec[p]*100,"%<br />g = ", gap_vec[g], "<br />f = ", round(data[p,g],2))
          }
        }
        
        txt_list[[M]] <- txt
        
        z[M] <- paste("add_surface(x=gap_vec,y=prop_vec,z=z_list[['",metric[s],"']][['",m[M],"']][[",d[vd],"]], 
                      hovertemplate = t(txt_list[[",M,"]]),
                      colorscale = list(seq(0,1,length.out=P*G), palette[['",m[M],"']]),
                      name = method_list_names[grepl('",m[M],"',method_list_names)], opacity = 1)",sep="")
        
        z <- paste(z, collapse = "")
        
        plotList[[s]][[vd]] <-  eval(parse(text = paste("plot_ly(scene='",paste("scene",vd,sep=""),"') %>%",
                                                        "layout(",paste("scene",vd,sep=""),"= list(
                                                        xaxis = axx,
                                                        yaxis = axy,
                                                        zaxis = axz
                                                        )) %>%",z,sep="")))
        
        plotList[[s]][[vd]] <- plotList[[s]][[vd]] %>%  
          layout(title = paste0("\n f = ", names(z_list[metric[s]])," (",f,")","\n Dataset = ",d[vd])) 
        
        plotList[[s]][[vd]] <- hide_colorbar(plotList[[s]][[vd]])
        
      }
      names(plotList[[s]]) <- data_list_names
    }
    names(plotList) <- metric
  }
  
  else if(layer_type == "dataset"){
    # fix the method.
    # layers are by dataset. 
    
    plotList <- lapply(plotList <- vector(mode = 'list', C), function(x)
      x <- vector(mode = 'list', M))
    
    axx <- list(
      nticks = length(gap_vec),
      range = c(min(gap_vec),max(gap_vec)),
      title = "g"
    )
    
    axy <- list(
      nticks = length(prop_vec),
      range = c(min(prop_vec),max(prop_vec)),
      title = "p"
    )
    
    axz <- list(nticks = 4, title = "f(p,g)")
    
    
    for(s in 1:C){
      for(vm in 1:M){
        z <- numeric(D)
        txt_list <- list()
        
        if(D > 1){
          for(vd in 1:(D-1)){
            
            data <- z_list[[metric[s]]][[m[vm]]][[d[vd]]]
            txt <- array(dim = dim(data))
            
            for(p in 1:length(rownames(data))){
              for(g in 1:length(colnames(data))){
                txt[p,g] <- paste0("p = ", prop_vec[p]*100,"%<br />g = ", gap_vec[g], "<br />f = ", round(data[p,g],2))
              }
              
              txt_list[[vd]] <- txt
            }
            
            z[vd] <- paste("add_surface(x=gap_vec,y=prop_vec,z=z_list[['",metric[s],"']][['",m[vm],"']][[",d[vd],"]], 
                            hovertemplate = t(txt_list[[",vd,"]]),
                           colorscale = list(seq(0,1,length.out=P*G), palette[[",vd,"]]),
                           name = names(z_list[[1]][[1]])[",d[vd],"], opacity = 1) %>% ",sep="")
          }
        }
        
        data <- z_list[[metric[s]]][[m[vm]]][[d[D]]]
        txt <- array(dim = dim(data))
        
        for(p in 1:length(rownames(data))){
          for(g in 1:length(colnames(data))){
            txt[p,g] <- paste0("p = ", prop_vec[p]*100,"%<br />g = ", gap_vec[g], "<br />f = ", round(data[p,g],2))
          }
        }
        
        txt_list[[D]] <- txt
        
        z[D] <- paste("add_surface(x=gap_vec,y=prop_vec,z=z_list[['",metric[s],"']][['",m[vm],"']][[",d[D],"]],
                      hovertemplate = t(txt_list[[",D,"]]),
                      colorscale = list(seq(0,1,length.out=P*G), palette[[",D,"]]),
                      name = names(z_list[[1]][[1]])[",d[D],"], opacity = 1)",sep="")
        
        z <- paste(z, collapse = "")
        
        plotList[[s]][[vm]] <- eval(parse(text = paste("plot_ly(scene='",paste("scene",vm,sep=""),"') %>%",
                                                       "layout(",paste("scene",vm,sep=""),"= list(
                                                       xaxis = axx,
                                                       yaxis = axy,
                                                       zaxis = axz
                                                       )) %>%",
                                                       z,sep="")))
        
        plotList[[s]][[vm]] <- plotList[[s]][[vm]] %>%  layout(title = paste("\n f = ",names(z_list[metric[s]])," (",f,")","\n Method = ",method_list_names[vm], sep = ""))
        
        plotList[[s]][[vm]] <- hide_colorbar(plotList[[s]][[vm]])
      }
      names(plotList[[s]]) <- method_list_names
    }
    names(plotList) <- metric
  }  
  
  return(plotList)
  
  
}
