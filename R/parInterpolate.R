#' Parallel Interpolation 
#' 
#' Function to perform interpolation on gappy series in parallel using user-specified and/or user-defined interpolation methods. Parallelization occurs over the K level. \cr\cr
#' 
#' @details Below is a list of the built-in interpolators:\cr
#' \enumerate{
#' \item \code{NN}; Nearest Neighbor
#' \item \code{LI}; Linear Interpolation
#' \item \code{NCS}; Natural Cubic Spline
#' \item \code{FMM}; Cubic Spline
#' \item \code{HCS}; Hermite Cubic Spline
#' \item \code{SI}; Stineman Interpolation
#' \item \code{KAF}; Kalman ARIMA
#' \item \code{KSF}; Kalman StructTS
#' \item \code{LOCF}; Last Observation Carried Forward
#' \item \code{NOCB}; Next Observation Carried Backward
#' \item \code{SMA}; Simple Moving Average
#' \item \code{LWMA}; Linear Weighted Moving Average
#' \item \code{EWMA}; Exponential Weighted Moving Average
#' \item \code{RMEA}; Replace with Mean
#' \item \code{RMED}; Replace with Median
#' \item \code{RMOD}; Replace with Mode
#' \item \code{RRND}; Replace with Random
#' \item \code{HWI}; Hybrid Wiener Interpolato
#' }
#' 
#' @param GappyData \code{list}; A list of dimension D x P x G x K containing gappy time series.
#' @param methods \code{character}; A vector of IDs for selected interpolation methods, where m = 1,...,M
#' @param FUN_CALL \code{character}; User-specified interpolation function(s) to be applied to GappyData. Must be a character string in the form: `function_name(args = ..., x = `.
#' @param numCores \code{integer}; How many CPU cores to use. The default is to use the total number of available cores, as determined by `detectCores()`.
#' @param parallel \code{character}; Over which index to parallelize. Possible choices: "p","g","k"
#' 
#' 
#' @examples
#'# Built-in interpolators
#'methods <- c(17,5) # Replace with Random, Hermite Cubic Spline
#'
#'# User-defined functions to pass to FUN_CALL
#'## Toy function 1: Convert each value of x to its index position
#'plus <- function(x){
#'vec <- numeric(length(x))
#'for(i in 1:length(vec)){
#'  vec[i] <- i
#'}
#'return(vec)
#'}
#'
#'## Toy function 2: Convert each value of x to its negative index position
#'minus <- function(x){
#'  vec <- numeric(length(x))
#'  for(i in 1:length(vec)){
#'    vec[i] <- -i
#'  }
#'  return(vec)
#'}
#'
#'FUN_CALL <- c("plus(","minus(")
#'
#' # Interpolation
#' 
#'  IntData <- parInterpolate(GappyData = GappyData, methods = methods, FUN_CALL = FUN_CALL)
#'  
#'  # dimension D x M x P x G x K 
#'  



parInterpolate <- function(GappyData, methods = NULL, FUN_CALL = NULL, numCores = detectCores(), parallel = "k"){
  
  # CALLING REQUIRED LIBRARIES
  #require(multitaper)
  #require(tsinterp)
  #require(imputeTS)
  #require(zoo)
  #require(forecast)
  #require(MASS)
  #require(snow)
  #require(parallel)
  
  stopifnot(!(is.null(methods) && is.null(FUN_CALL)), 
            !(is.null(GappyData)),
            (parallel == "p" | parallel == "g" | parallel == "k"))
  
  # check that FUN_CALL is in the correct format
  if(!(is.null(FUN_CALL))){
    
    # check to see that output of FUN_CALL is a single numeric vector with no NAs
    test_data <- rnorm(1000)
    test_index <- sample(1:1000,20)
    test_data[test_index] <- NA
    
    for(l in 1:length(FUN_CALL)){
      test_str <- paste0(FUN_CALL[l],"test_data)")
      test_eval <- eval(parse(text = test_str))
      
      if(!is.numeric(test_eval) && !is.ts(test_eval)) stop(paste0("Output of '",FUN_CALL[l],"' passed to FUN_CALL is not of class 'numeric' or 'ts'.  Please redefine '",FUN_CALL[l],"' to return a single numeric vector of the repaired series."))
      if(sum(is.na(test_eval) != 0))  stop(paste0("Output of '",FUN_CALL[l],"' still contains missing values."))
    }
  }
  
  # DEFINING Nearest Neighbor INTERPOLATION
  nearestNeighbor <- function(x) {
    stopifnot(is.ts(x) | is.numeric(x)) 
    
    findNearestNeighbors <- function(x, i) {
      leftValid <- FALSE
      rightValid <- FALSE 
      numItLeft <- 1
      numItRight <- 1
      while (!leftValid) {
        leftNeighbor <- x[i - numItLeft]
        if (!is.na(leftNeighbor)) {
          leftValid <- TRUE
          leftNeighbor <- i - numItLeft
        }
        numItLeft <- numItLeft + 1
      }
      while (!rightValid) {
        rightNeighbor <- x[i + numItRight]
        if (!is.na(rightNeighbor)) {
          rightValid <- TRUE
          rightNeighbor <- i + numItRight
        }
        numItRight <- numItRight + 1
      }
      return(c(leftNeighbor, rightNeighbor))
    }
    
    for (i in 1:length(x)) {
      if (is.na(x[i])) {
        nearestNeighborsIndices <- findNearestNeighbors(x, i)
        a <- nearestNeighborsIndices[1]
        b <- nearestNeighborsIndices[2]
        if (i < ((a + b) / 2)) {
          x[i] <- x[a]
        } else {
          x[i] <- x[b]
        }
      }
    }
    return(x)
  }
  
  
  
  
  # ACCEPTABLE ALGORITHM CALLS AND ABBREVIATIONS
  
  algorithm_calls <- c("nearestNeighbor(", 
                       "na.approx(", 
                       "na.spline(method = 'natural', object = ",
                       "na.spline(method = 'fmm', object = ", 
                       "na.spline(method = 'monoH.FC', object = ", 
                       "na_interpolation(option = 'stine', x = ", 
                       "na_kalman(model = 'auto.arima', x = ", 
                       "na_kalman(model = 'StructTS', x = ",
                       "imputeTS::na.locf(option = 'locf', x = ", 
                       "imputeTS::na.locf(option = 'nocb', x = ", 
                       "na_ma(weighting = 'simple', x = ",
                       "na_ma(weighting = 'linear', x = ", 
                       "na_ma(weighting = 'exponential', x = ",
                       "na_mean(option = 'mean', x = ", 
                       "na_mean(option = 'median', x = ",
                       "na_mean(option = 'mode', x = ", 
                       "na_random(",
                       "tsinterp::interpolate(gap = which(is.na(x) == TRUE), progress = FALSE, z = ")
  
  if(!(is.null(FUN_CALL))){
    algorithm_calls <- c(algorithm_calls, paste0(FUN_CALL))
  }
  
  algorithm_names <- c("NN",
                       "LI", 
                       "NCS",
                       "FMM", 
                       "HCS",
                       "SI",
                       "KAF",
                       "KKSF",
                       "LOCF",
                       "NOCB", 
                       "SMA", 
                       "LWMA",
                       "EWMA",
                       "RMEA",
                       "RMED", 
                       "RMOD",
                       "RRND",
                       "HWI")
  
  user_fun = NULL
  
  if(!(is.null(FUN_CALL))){
    
    FUN_call <- numeric(length(FUN_CALL))
    
    for(l in 1:length(FUN_CALL)){
      FUN_call[l] <- paste0(FUN_CALL[l],"x",")")
    }
    user_fun = sub("\\(.*", "", FUN_call)
    algorithm_names = c(algorithm_names, user_fun)
  }
  
  algorithms <- data.frame(algorithm_names, algorithm_calls)
  
  
  # LOGICAL CHECKS
  
  if(!(is.null(methods))){
    if(!all(methods %in% algorithm_names)) stop(paste0("Method '", methods[!(methods %in% algorithm_names)],
                                                       "' not found.  Please make your selection from the following list: '", 
                                                       paste0(algorithm_names, collapse = "' , '"), "'."))
  }
  
  fun_names <- c(methods,user_fun)
  method_index <- match(fun_names,algorithm_names)
  
  D <- length(GappyData)
  M <- length(fun_names)
  P <- length(GappyData[[1]])
  G <- length(GappyData[[1]][[1]])
  K <- length(GappyData[[1]][[1]][[1]])
    
  #Creating a list object to store interpolated series
  int_series <- lapply(int_series <- vector(mode = 'list', M),function(x)
                    lapply(int_series <- vector(mode = 'list', P),function(x) 
                      lapply(int_series <- vector(mode = 'list', G),function(x) 
                        x<-vector(mode='list', K))))
  
  ## INTERPOLATION
  int_data <- list()
  
  for(d in 1:D){
   
    if(parallel == "p"){
      
      for(m in 1:length(method_index)){ 
        
        if(fun_names[m] == "HWI"){
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")","[[1]]")
        }
        else{
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")")
        }
        
        int_series[[m]] <- mclapply(GappyData[[d]], function(x){
                            lapply(x, function(x){
                              lapply(x, function(x){
                                eval(parse(text = function_call))})})}, mc.cores = numCores)
      }
    }
    
    if(parallel == "g"){
      for(m in 1:length(method_index)){ 
        
        if(fun_names[m] == "HWI"){
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")","[[1]]")
        }
        else{
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")")
        }
        
        int_series[[m]] <- lapply(GappyData[[d]], function(x){
                              mclapply(x, function(x){
                                lapply(x, function(x){
                                  eval(parse(text = function_call))})}, mc.cores = numCores)})
      }
    }
    
    
    if(parallel == "k"){
      for(m in 1:length(method_index)){ 
        
        if(fun_names[m] == "HWI"){
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")","[[1]]")
        }
        else{
          function_call <- paste0(algorithm_calls[method_index[m]], "x", ")")
        }
        
        int_series[[m]] <- lapply(GappyData[[d]], function(x){
                            lapply(x, function(x){
                              mclapply(x, function(x){
                                eval(parse(text = function_call))}, mc.cores = numCores)}
          )})
      }
    }
    
    names(int_series) <- c(fun_names) 
    int_data[[d]] <- int_series
    }
  
  names(int_data) <- names(GappyData)
  
  return(int_data)
}





