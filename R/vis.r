#' vis
#' 
#' A visualizaiton for univariate and multivariate regressions showing coefficient, confidence intervals and p-values
#' @param out a length 2 list univariate and final models: list(screen=several_univariate_models,final=one_multivariate_model). Either screen or final may be set to NULL. Accepts: lm, glm, lmer, glmer
#' @param family a character indicating the glm family fit for the model. If 'binomial' vis_logit will be run. Otherwise standard output is produced.
#' @param Pr an optional numeric vector of the same length and order as out$screen. If the user wants to specify univariate p-values they may do so here. Otherwise the wald test for the 1st variable in the model will be used.
#' @param fullUnivariate visualizes all variables in each univariate model
#' @param intercept boolean indicating if the intercept should be visualized. True by default.
#' @param col_scheme a grDevices::Palettes to specify the color scheme representing -log10(p-values). rainbow(4) by default.
#' @return a list of 2 ggplot2 objects visualizing the univariate screening and multivariate final model.
#' @export
#' @import ggplot2
#' @import grDevices
#' @import MASS
#' @import fastcluster
#' @import glmnet
#' @import reshape
#' @import data.table
#' @import easyGgplot2
vis <- function(out,family='gaussian',Pr=NULL,fullUnivariate=FALSE,intercept=TRUE,col_scheme=rainbow(4),...){
  if(!is.character(family)){stop('family must be a character vector')}
  if(family=='binomial'){ return(vis_logit(out,family,Pr,fullUnivariate,intercept,col_scheme,...)) }
  
  multi=NULL; uni=NULL
  
  mod1 = out$final
  screen= out$screen
  
  ### Multivariate visuals
  if(!is.null(out$final)){
    summary_df <- as.data.frame(cbind( cbind(coefficients = coef(mod1), confint(mod1)) , coef(summary(mod1)) ))
    summary_df$vars = factor( rownames(summary_df) , levels = rownames(summary_df)[order(summary_df$Estimate)] )
    colnames(summary_df)[c(2:3,7)] = c('X2.5','X97.5','Pr')
    
    limits <- aes(ymax = X97.5, ymin=X2.5)
    if(intercept){
      p <- ggplot(summary_df, aes(x=vars, y=coefficients,color=-log(Pr,10))) + geom_hline(yintercept=0)
    }else{
      p <- ggplot(summary_df[-1,], aes(x=vars, y=coefficients,color=-log(Pr,10))) + geom_hline(yintercept=0)
    }
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_colour_gradientn(colours=col_scheme) # + scale_y_continuous(trans=trans)
    #p <- p +                                   scale_colour_gradientn(colours=col_scheme)
    multi = p
  }
  
  ### Full Univariate Visuals
  if(fullUnivariate){
    for(i in 1:length(screen)){
      mod1 = screen[[i]]
      summary_df <- as.data.frame(cbind( cbind(coefficients = coef(mod1), confint(mod1)) , coef(summary(mod1)) ))
      summary_df$vars = factor( rownames(summary_df) , levels = rownames(summary_df)[order(summary_df$Estimate)] )
      colnames(summary_df)[c(2:3,7)] = c('X2.5','X97.5','Pr')
      summary_df$var_i = names(screen)[i]
      if(i==1){
        df = summary_df
      }else{
        df = rbind(df,summary_df)
      }
    }
    
    limits <- aes(ymax = X97.5, ymin=X2.5)
    p <- ggplot(df[-1,], aes(x=vars, y=Odds_Ratio,color=-log(Pr,10))) + facet_wrap(~ var_i) + geom_hline(yintercept=0)
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_colour_gradientn(colours=col_scheme) # + scale_y_continuous(trans=trans)
    uni = p
    
    return(list(multivar=multi,univar=uni)) # early return
  }
  
  ### Univariate model
  if(!is.null(out$screen)){
    screen_tmp = list()
    for(i in names(screen)){
      if(!is.na(coef(screen[[i]])[2])){ screen_tmp[[i]] = screen[[i]] }
    }
    screen = screen_tmp
#    screen_df = as.data.frame( cbind( do.call(rbind,lapply(screen,function(x) coef(summary(x))[2,]  ) ) , 
#                                      do.call(rbind,lapply(screen,function(x) cbind(coefficients = coef(x), confint(x))[2,]  ) )
#    ) )
    if(any(class(screen[[1]])%in%c('glm','lm'))){
      screen_df = as.data.frame( cbind( do.call(rbind,lapply(screen,function(x) coef(summary(x))[2,] ) ) , 
                                        do.call(rbind,lapply(screen,function(x) cbind(coefficients = coef(x), confint(x))[2,] ) )
      ) )
    }else if(any(class(screen[[1]])%in%c('glmerMod','lmerMod'))){
      screen_df = as.data.frame( cbind( do.call(rbind,lapply(screen,function(x) coef(summary(x))[2,] ) ) , 
                                        do.call(rbind,lapply(screen,function(x) cbind(coefficients=coef(summary(x))[,1], confint(x)[-1,])[2,] ) )
      ) )
    }
    screen_df$vars = factor( rownames(screen_df) , levels = rownames(screen_df)[order(screen_df$Estimate)] )
    colnames(screen_df)[c(4,6:7)] = c('Pr', 'X2.5','X97.5')
    if(!is.null(Pr)){ screen_df$Pr = Pr }
    screen_df = screen_df[order(screen_df$Estimate),]
    limits <- aes(ymax = X97.5, ymin=X2.5)
    p <- ggplot(screen_df, aes(x=vars, y=coefficients,color=-log(Pr,10))) + geom_hline(yintercept=0)
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_colour_gradientn(colours=col_scheme) # + scale_y_continuous(trans=trans)
    uni = p
  }
  
  return(list(multivar=multi,univar=uni))
}

######################

#' vis_logit
#' 
#' A visualizaiton for logit regressions that calculates Odds Ratios (OR)
#' @param out a length 2 list univariate and final models: list(screen=several_univariate_models,final=one_multivariate_model). Either screen or final may be set to NULL. Accepts: lm, glm, lmer, glmer
#' @param Pr an optional numeric vector of the same length and order as out$screen. If the user wants to specify univariate p-values they may do so here. Otherwise the wald test for the 1st variable in the model will be used.
#' @param fullUnivariate visualizes all variables in each univariate model
#' @param intercept boolean indicating if the intercept should be visualized. True by default.
#' @param trans a character indicating the transformation for the y-axis: log2, log10, sqrt. Refers to the trans parameter of scale_y_continuous. log2 by default.
#' @param col_scheme a grDevices::Palettes to specify the color scheme representing -log10(p-values). rainbow(4) by default.
#' @return a list of 2 ggplot2 objects visualizing the univariate screening and multivariate final model.
#' @import ggplot2
#' @import grDevices
#' @export
vis_logit <- function(out,Pr=NULL,fullUnivariate=FALSE,intercept=TRUE,trans='log2',col_scheme=rainbow(4)){
  multi=NULL; uni=NULL
  
  mod1 = out$final
  screen= out$screen
  
  ### Multivariate visuals
  if(!is.null(out$final)){
    summary_df <- as.data.frame(cbind( exp(cbind(Odds_Ratio = coef(mod1), confint(mod1))) , coef(summary(mod1)) ))
    summary_df$vars = factor( rownames(summary_df) , levels = rownames(summary_df)[order(summary_df$Estimate)] )
    
    colnames(summary_df)[c(2:3,7)] = c('X2.5','X97.5','Pr')
    
    limits <- aes(ymax = X97.5, ymin=X2.5)
    if(intercept){
      p <- ggplot(summary_df, aes(x=vars, y=Odds_Ratio,color=-log(Pr,10))) + geom_hline(yintercept=1)
    }else{
      p <- ggplot(summary_df[-1,], aes(x=vars, y=Odds_Ratio,color=-log(Pr,10)))+ geom_hline(yintercept=1)
    }
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_y_continuous(trans=trans) + scale_colour_gradientn(colours=col_scheme)
    multi = p
  }
  
  ### Full Univariate Visuals
  if(fullUnivariate){
    for(i in 1:length(screen)){
      mod1 = screen[[i]]
      summary_df <- as.data.frame(cbind( exp(cbind(Odds_Ratio = coef(mod1), confint(mod1))) , coef(summary(mod1)) ))
      summary_df$vars = factor( rownames(summary_df) , levels = rownames(summary_df)[order(summary_df$Estimate)] )
      colnames(summary_df)[c(2:3,7)] = c('X2.5','X97.5','Pr')
      summary_df$var_i = names(screen)[i]
      if(i==1){
        df = summary_df
      }else{
        df = rbind(df,summary_df)
      }
    }
    
    limits <- aes(ymax = X97.5, ymin=X2.5)
    p <- ggplot(df[-1,], aes(x=vars, y=Odds_Ratio,color=-log(Pr,10))) + facet_wrap(~ var_i) + geom_hline(yintercept = 1)
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_y_continuous(trans=trans) + scale_colour_gradientn(colours=col_scheme)
    uni = p
    
    return(list(multivar=multi,univar=uni)) # early return
  }
  
  ### Univariate visuals
  if(!is.null(out$screen)){
    screen_tmp = list()
    for(i in names(screen)){
      if(!is.na(coef(screen[[i]])[2])){ screen_tmp[[i]] = screen[[i]] }
    }
    screen = screen_tmp
    if(any(class(screen[[1]])%in%c('glm','lm'))){
      screen_df = as.data.frame( cbind( do.call(rbind,lapply(screen,function(x) coef(summary(x))[2,] ) ) , 
                                        do.call(rbind,lapply(screen,function(x) exp(cbind(Odds_Ratio = coef(x), confint(x)))[2,] ) )
      ) )
    }else if(any(class(screen[[1]])%in%c('glmerMod','lmerMod'))){
      screen_df = as.data.frame( cbind( do.call(rbind,lapply(screen,function(x) coef(summary(x))[2,] ) ) , 
                                        do.call(rbind,lapply(screen,function(x) exp(cbind(Odds_Ratio=coef(summary(x))[,1], confint(x)[-1,]))[2,] ) )
      ) )
    }
    screen_df$vars = factor( rownames(screen_df) , levels = rownames(screen_df)[order(screen_df$Estimate)] )
    colnames(screen_df)[c(4,6:7)] = c('Pr', 'X2.5','X97.5')
    if(!is.null(Pr)){ screen_df$Pr = Pr }
    screen_df = screen_df[order(screen_df$Estimate),]
    limits <- aes(ymax = X97.5, ymin=X2.5)
    p <- ggplot(screen_df, aes(x=vars, y=Odds_Ratio,color=-log(Pr,10)))+ geom_hline(yintercept=1)
    p <- p + geom_point() + geom_errorbar(limits, width=0.2) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
    p <- p + scale_y_continuous(trans=trans) + scale_colour_gradientn(colours=col_scheme)
    uni = p
  }
  
  return(list(multivar=multi,univar=uni))
}

#' vis_reg
#' 
#' Visualize prototypical models for glmnets
#' @param l_reg list of glmnet.cv objects
#' @param k number of prototype models to extract
#' @return a list of the selected most prototypical models, 3 ggplot2 objects visualizing the coefficient, Average(coef.) and Sd(coef.) of l_reg models,
#'         and 3 matrix for plotting these 3 ggplot2 objects.
vis_reg <- function(l_reg,k=4){
  # check that l_reg is multiple glmnet.cv objects
  if(!(length(l_reg)>1 & all(sapply(l_reg,class)=='cv.glmnet'))){stop('l_reg must be multiple glmnet.cv objects')}
  # make matrix of coefficients
  l=lapply(l_reg,function(x) data.matrix(coef(x,s=x$lambda.min+.1*(x$lambda.1se-x$lambda.min))))
  l=lapply(l,function(x) x[order(rownames(x)),])
  m=do.call(rbind,l)
  # cluster
  fit = hclust(dist(m))
  # cut
  groups = cutree(fit, k=k) # todo, choose k riggerously 
                            # Need to think about: how to choose k riggerously?
  

  # Plot01 - Original version 
  # get average coefficient for each gene in each group
  m <- m[,-1]
  m <- m[,colSums(m^2) !=0]
  m <- cbind(m,groups)
  p1 <- getPlot(m, xlab="Models", ylab="Genes", legendname="Coefficient",reorderList=NULL)

  # Plot02 (Average) &  Plot03 (Variance)
  # get average of coefficient for each gene in each group
  m2 <- matrix(data = NA, ncol = ncol(m), nrow = k)
  m3 <- matrix(data = NA, ncol = ncol(m), nrow = k)
  colnames(m2) <- colnames(m)
  colnames(m3) <- colnames(m)
  for(g in 1:k){
    idx <- which(m[,'groups']==g)
    m_tmp = m[idx,]
    if(length(idx) > 1){
      m2[g,] <- apply(m_tmp,2,mean)
      m3[g,] <- apply(m_tmp,2,sd)
    } else {
      m2[g,] <- m_tmp
      m3[g,] <- 0
    }
  }
  m3[,'groups'] <- c(1:k)

  p2 <- getPlot(m2, xlab="Model Group", ylab="Genes", 
                legendname="Avg(coef)",reorderList=p1$reorderList)
  p3 <- getPlot(m3, xlab="Model Group", ylab="Genes", 
                legendname="Sd(coef)",reorderList=p1$reorderList)
  
  # return k models that are the centroids (most average) of each major cluster
  sel_return=list()
  for(g in 1:k){
    idx <- which(m[,'groups']==g)
    m_tmp = m[idx,]
    if(length(idx) > 1){
      m_tmp <- m_tmp[, !(colnames(m_tmp) %in% c("groups"))]
      m_tmp <- m_tmp[,colSums(m_tmp^2) !=0]
      mean = apply(m_tmp,2,mean) #avg for each gene coefficient
      sd = apply(m_tmp,2,sd) #var for each gene coefficient
      z = apply(m_tmp,1,function(x) sum(abs((x-mean)/sd)) )
      indx_tmp = which.min(z)
      # change back to original index -> indx
      indx = idx[indx_tmp]
      sel_return[[g]] = l_reg[[indx]]
    } else {
      indx = idx[1]
      sel_return[[g]] = l_reg[[indx]]
    }
  }
  return(list(sel_return=sel_return, 
              m=m,m2=m2,m3=m3,
              p1=p1$p,p2=p2$p,p3=p3$p))
}

getPlot <- function(m, xlab, ylab, legendname,reorderList=NULL){
  m.dt <- as.data.table(m)
  m.dt[,model_number:= rownames(m.dt)]
  melt_m <- melt(m.dt, id.vars = c('groups','model_number'))
  colnames(melt_m) = c('groups','model_number','gene','coefficient')
  if(is.null(reorderList)){
    melt_m$gene <- reorder(melt_m$gene,melt_m$coefficient)
    reorderList <- levels(melt_m$gene)
  } else {
    melt_m$gene <- factor(melt_m$gene , levels = reorderList)
  }
  base_size <- 12
  p <- ggplot(data=melt_m, aes(x=model_number,y=gene)) + 
    geom_tile(aes(fill = coefficient)) +
    scale_fill_gradient2(name = legendname, 
                         low = "blue", high = "red", mid = "white", midpoint = 0) +
    theme_grey(base_size = base_size) + 
    labs(x = xlab, y = ylab) +
    facet_grid(  .~groups, scales = "free", space = "free" ) +
    theme(axis.text.x = element_text(angle = 60, hjust = 1)) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.ticks.y = element_blank(),
      panel.border = element_rect(colour = "black", fill=NA, size=.5),
      axis.text.y = element_text(size = base_size * .7, 
                                 angle = 0, hjust = 0, colour = "black"))
  return(list(p=p,reorderList=reorderList))
}

#' loading_vis
#' 
#' Visualize loadings of a PCA
#' @param res.pca a "prcomp" class object produced by PCA using prcomp
#' @param var_catgories an optional vector of categories into which each variable can be classified
#' @return a ggplot2 object showing the loadings of the 
#' @import ggplot2
#' @import grDevices
#' @export
loading_vis<-function(res.pca,var_catgories=NULL){
  ### Visualize contributors to PCs
  rot = res.pca$rotation[,keep_all]
  tmp = melt(rot)
  colnames(tmp) = c('Variables','PC','Loadings')
  tmp$PC = factor(tmp$PC,levels=levels(tmp$PC)[order(as.numeric(gsub('PC','',levels(tmp$PC))))])
  tmp$Variables = factor(tmp$Variables,rownames(rot))
  if(!is.null(var_catgories)){
    tmp$Source = factor(var_catgories)
  }
  
  g=ggplot(data=tmp,aes(y=Variables,x=Loadings,color=Source))+ geom_point()+
    geom_segment(aes(x = 0 , y = Variables, xend = Loadings, yend = Variables, size=abs(Loadings), colour = factor(sign(Loadings)) ) ) +
    facet_wrap(~PC,nrow=1) # + theme(axis.text.x = element_text(angle = 90, hjust = 1,size=5))
  g
}



