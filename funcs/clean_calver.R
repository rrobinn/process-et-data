clean_calver <- function(precisionInfo) {
  
  # Determine if output is already summarized at participant level
  if (n_distinct(precisionInfo[,1])==nrow(precisionInfo)) { # Precision Info already summarized 
    summary=1
  }else{
    summary=0
  }
  
  if (summary) {
    precisionInfo2=precisionInfo %>%
      dplyr::select(id=ID,
             AvgPrecision)
    # Generate data-driven threshold for which sessions to be excluded
    cutoff=mean(precisionInfo2$AvgPrecision, na.rm=TRUE)+2*(sd(precisionInfo2$AvgPrecision,na.rm=TRUE))
    precisionInfo2=precisionInfo2%>%
      filter(AvgPrecision<cutoff) # remove trials above the acceptable cutoff (not included in final sample)
    avg_prec=precisionInfo2
  } else{
    
    
    precisionInfo2 = precisionInfo %>%
      filter(!is.na(CoordX)) %>% # If missing info for X, always missing for Y as well
      mutate(Precision_RMS_X_Y=(PrecRMSx+PrecRMSy)/2) 
    
    if ( length(intersect(colnames(precisionInfo2), 'Order')) != 0 ) { 
      precisionInfo2 = precisionInfo2 %>%
        dplyr::select(id=X, Precision_RMS_X_Y, Stimulus,Order) %>%
        distinct()
    }else {
      precisionInfo2 = precisionInfo2 %>%
        dplyr::select(id=X, Precision_RMS_X_Y, Stimulus) %>%
        distinct()
      }
    
    
    #Establish threshold for acceptable precision value based on 2 SDs above sample mean
    cutoff=mean(precisionInfo2$Precision_RMS_X_Y, na.rm=TRUE)+2*sd(precisionInfo2$Precision_RMS_X_Y, na.rm=TRUE)
    
    # Remove bad points from data
    precisionInfo3=precisionInfo2 %>%
      filter(Precision_RMS_X_Y<cutoff)
    
    #Summarize mean precision for each participant
    avg_prec=precisionInfo3%>%
      filter(Precision_RMS_X_Y<cutoff) %>%# remove trials above the acceptable cutoff (not included in final sample)
      group_by(id)%>%
      summarise(AvgPrecision=mean(Precision_RMS_X_Y)) %>%
      ungroup() %>%
      mutate(id=as.character(id))
    
    # Add back in participants with bad precision
    excludedSess=setdiff(precisionInfo2$id, precisionInfo3$id)
    temp=data.frame(id=excludedSess, AvgPrecision=999)
    avg_prec=rbind(avg_prec,temp)
    
  }
  out=list(cutoff,avg_prec)
  
  
}
