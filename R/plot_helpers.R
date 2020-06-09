.plot_roc <- function(labels, predictions, title = NULL, legend_pos = c(0.78, 0.275),
                      freq_default = 0.05, plot_point = TRUE) {
  predictions <- as.matrix(predictions)
  roc_data <- c()
  for (i in 1:ncol(predictions)) {
    name <- colnames(predictions)[i]
    pred <- ROCR::prediction(-predictions[,i], labels)
    res <- ROCR::performance(pred, "tpr", "fpr")
    auc <- round(ROCR::performance(pred, "auc")@y.values[[1]], 3)
    x <- res@x.values[[1]]
    y <- res@y.values[[1]]
    bayes <- (name == 'polyatree')
    dot <- .get_roc_point(labels, predictions[,i], bayes, freq_default)
    info <- ifelse(is.na(auc), name, paste(name, ' (', auc, ')', sep = ""))
    roc_data[[name]] <- list(data = data.frame(x = x, y = y), 
                             point = data.frame(x = dot$fpr, y = dot$tpr), 
                             info = info)
  }
  
  plt <- ggplot2::ggplot() + 
    ggplot2::labs(x = "False Positive Rate", y = "True Positive Rate", title = title) +
    ggplot2::theme(legend.title = ggplot2::element_text(size = 0),
                   legend.spacing.x = ggplot2::unit(0.2, 'cm'),
                   legend.position = legend_pos,
                   plot.title = ggplot2::element_text(size = 12, hjust = 0.5))
  for (roc in roc_data) {
    c <- roc$info
    plt <- plt + ggplot2::geom_line(data = roc$data, ggplot2::aes(x, y, colour = {{c}}))
    if (plot_point) {
      plt <- plt + ggplot2::geom_point(data = roc$point, ggplot2::aes(x, y, colour = {{c}}))
    }
  }
  
  return(plt)
}

.plot_roc_custom <- function(labels, ts_res, uci_res, ci_res, 
                             title = NULL, plot_point = TRUE, option = 0) {
  roc_data <- c()
  for (i in 1:ncol(ts_res)) {
    name <- colnames(ts_res)[i]
    bayes <- (name == 'polyatree' || name == 'ppcor_b')
    roc <- .lcd_roc(labels, ts_res[,i], uci_res[,i], ci_res[,i], bayes, option)
    dot <- .lcd_roc_dot(labels, ts_res[,i], uci_res[,i], ci_res[,i], bayes)
    info <- ifelse(is.na(roc$auc), name, paste(name, ' (', roc$auc, ')', sep = ""))
    roc_data[[name]] <- list(data = data.frame(x = roc$fpr, y = roc$tpr), 
                             point = data.frame(x = dot$fpr, y = dot$tpr), 
                             info = info)
  }
  
  plt <- ggplot2::ggplot() +
    ggplot2::xlim(0, 1) +
    ggplot2::ylim(0, 1) +
    ggplot2::labs(x = "False Positive Rate", y = "True Positive Rate", title = title) +
    ggplot2::theme(legend.title = ggplot2::element_text(size = 0),
                   legend.spacing.x = ggplot2::unit(0.2, 'cm'),
                   legend.position = c(0.78, 0.275),
                   plot.title = ggplot2::element_text(size = 12, hjust = 0.5))
  for (roc in roc_data) {
    c <- roc$info
    
    if (option == 1) {
      plt <- plt + ggplot2::geom_path(data = roc$data, ggplot2::aes(x, y, colour = {{c}}))
    } else {
      plt <- plt + ggplot2::geom_line(data = roc$data, ggplot2::aes(x, y, colour = {{c}}))
    }
    
    if (plot_point) {
      plt <- plt + ggplot2::geom_point(data = roc$point, ggplot2::aes(x, y, colour = {{c}}))
    }
  }
  
  return(plt)
}

.lcd_roc <- function(labels, ts, uci, ci, bayes, option = 0) {
  alphas <- sort(c(ts, uci, ci), TRUE)
  alphas <- alphas[alphas != 0]
  
  false <- which(labels == 0)
  true <- which(labels == 1)
  
  n <- length(labels)
  a0 <- ifelse(bayes, 0.5, 1/(5*sqrt(n)))
  
  fp <- c()
  tp <- c()
  for (alpha in rev(alphas)) {
    idx <- which(ts <= alpha)
    idx <- intersect(idx, which(uci <= alpha))
    if (option == 0) {
      idx <- intersect(idx, which(ci >= min(a0, 1-alpha)))
    } else if (option == 1) {
      idx <- intersect(idx, which(ci >= alpha))
    } else if (option == 2) {
      idx <- intersect(idx, which(ci >= 1-alpha))
    }
    
    tp <- c(tp, length(intersect(idx, true)))
    fp <- c(fp, length(intersect(idx, false)))
  }
  
  tpr <- tp / length(true)
  fpr <- fp / length(false)
  
  if (option == 1) {
    return(list(tpr = c(0, tpr), fpr = c(0, fpr), auc = NaN))
  } else {
    auc <- .get_auc(tpr, fpr)
    return(list(tpr = c(0, tpr, 1), fpr = c(0, fpr, 1), auc = auc))
  }
}

.get_roc_point <- function(labels, predictions, bayes, freq_default = 0.05) {
  true <- which(labels == 0)
  false <- which(labels == 1)
  n <- length(labels)
  alpha <- ifelse(bayes, 0.5, freq_default)
  idx <- which(predictions <= alpha)
  tpr <- length(intersect(idx, true)) / length(true)
  fpr <- length(intersect(idx, false)) / length(false)
  return(list(tpr = tpr, fpr = fpr))
}

.lcd_roc_dot <- function(labels, ts, uci, ci, bayes) {
  false <- which(labels == 0)
  true <- which(labels == 1)
  n <- length(labels)
  alpha <- ifelse(bayes, 0.5, 0.01)
  idx <- which(ts <= alpha)
  idx <- intersect(idx, which(uci <= alpha))
  idx <- intersect(idx, which(ci >= alpha))
  tpr <- length(intersect(idx, true)) / length(true)
  fpr <- length(intersect(idx, false)) / length(false)
  return(list(tpr = tpr, fpr = fpr))
}

.get_auc <- function(tpr, fpr) {
  if (0 < min(fpr)) {
    tpr <- c(min(tpr)/2, min(tpr)/2, tpr)
    fpr <- c(0, min(fpr), fpr)
  }
  if (max(fpr) < 1) {
    tpr <- c(tpr, 1 - (1-max(tpr))/2, 1 - (1-max(tpr))/2)
    fpr <- c(fpr, max(fpr), 1)
  }
  auc <- round(sum(tpr[-1] * diff(fpr)), 3)
  return(auc)
}

.ggsave <- function (name, grid, width, height) {
  ggplot2::ggsave(
    paste(name, ".pdf", sep = ""),
    plot = grid, scale = 1,
    width = width,
    height = height,
    units = "cm", dpi = 300, limitsize = FALSE
  )
}

.graph_lines <- function(context, system, context_edges, system_edges, opts = "", opts_context = "") {
  opts <- ifelse(opts != "", sprintf(", %s", opts), "")
  opts_context <- ifelse(opts_context != "", sprintf(", %s", opts_context), "")
  output <- ""
  for (node in context) {
    output <- sprintf(
      "%s\n\"%s\"[label = \"%s\", shape = box%s];", 
      output, node, node, opts_context)
  }
  for (node in system) {
    output <- sprintf(
      "%s\n\"%s\"[label=\"%s\", shape=oval%s];", 
      output, node, node, opts)
  }
  for (i in 1:nrow(system_edges)) {
    output <- sprintf(
      "%s\n\"%s\"->\"%s\"[arrowtail=\"none\", arrowhead=\"normal\"%s];",
      output, system_edges[i, 1], system_edges[i, 2], opts)
  }
  for (i in 1:nrow(context_edges)) {
    output <- sprintf(
      "%s\n\"%s\"->\"%s\"[arrowtail=\"none\", arrowhead=\"normal\", style=\"dashed\"%s];",
      output, context_edges[i, 1], context_edges[i, 2], opts_context)
  }
  
  return(output)
}

.output_graph <- function(results, path, name, alpha1, alpha2) {
  strong <- dplyr::filter(results, CX <= alpha1$strong, XY <= alpha1$strong, CY_X >= alpha2$strong)
  strong <- strong[,c('C', 'X', 'Y')]
  substantial <- dplyr::filter(results, CX <= alpha1$substantial, XY <= alpha1$substantial, CY_X >= alpha2$substantial)
  substantial <- substantial[,c('C', 'X', 'Y')]
  weak <- dplyr::filter(results, CX <= alpha1$weak, XY <= alpha1$weak, CY_X >= alpha2$weak)
  weak <- weak[,c('C', 'X', 'Y')]
  output <- "digraph G {"
  
  context1 <- unique(as.character(strong[,'C']))
  system1 <- unique(c(as.character(strong[,'X']), as.character(strong[,'Y'])))
  context_edges1 <- unique(strong[,c('C', 'X')])
  system_edges1 <- unique(strong[,c('X', 'Y')])
  output <- paste(output, .graph_lines(context1, system1, context_edges1, system_edges1, 
                                       "color=\"#000000\"",
                                       "color=\"#c4c4c4\""), sep = "")
  
  diff <- dplyr::setdiff(substantial, strong)
  context2 <- dplyr::setdiff(unique(as.character(diff[,'C'])), context1)
  system2 <- dplyr::setdiff(unique(c(as.character(diff[,'X']), as.character(diff[,'Y']))), system1)
  context_edges2 <- dplyr::setdiff(unique(diff[,c('C', 'X')]), context_edges1)
  system_edges2 <- dplyr::setdiff(unique(diff[,c('X', 'Y')]), system_edges1)
  output <- paste(output, .graph_lines(context2, system2, context_edges2, system_edges2, 
                                       "color=\"#e30505\"",
                                       "color=\"#ffa1a1\""), sep = "")
  
  diff <- dplyr::setdiff(weak, substantial)
  context3 <- dplyr::setdiff(unique(as.character(diff[,'C'])),
                             c(context1, context2))
  system3 <- dplyr::setdiff(unique(c(as.character(diff[,'X']), as.character(diff[,'Y']))),
                            c(system1, system2))
  context_edges3 <- dplyr::setdiff(unique(diff[,c('C', 'X')]),
                                   rbind(context_edges1, context_edges2))
  system_edges3 <- dplyr::setdiff(unique(diff[,c('X', 'Y')]),
                                  rbind(system_edges1, system_edges2))
  output <- paste(output, .graph_lines(context3, system3, context_edges3, system_edges3,
                                       "color=\"#0032fa\"",
                                       "color=\"#a8baff\""), sep = "")
  output <- paste(output, "}", sep = "\n")
  
  write(output, file = paste(path, name, ".dot", sep = ""))
}

.plot_times <- function(times, title = NULL) {
  times$time <- sapply(times$time, function(x) (x < 1.1)*1.1 + (x>= 1.1)*x)
  ggplot2::ggplot(data = times, ggplot2::aes(x = ensemble, y = time, fill = test)) +
    ggplot2::geom_col(position = ggplot2::position_dodge()) +
    ggplot2::labs(x = "Test ensemble", y = "Runtime (sec.)", title = title) + 
    ggplot2::scale_fill_discrete(name = "",
                                 breaks = c("1_ts", "2_uci", "3_ci"),
                                 labels = c("Two-sample", "Independence", "Conditional independence")) +
    ggplot2::theme(legend.position = c(0.703, 0.915),
                   legend.direction = "horizontal") +
    ggplot2::scale_y_log10(breaks = scales::trans_breaks("log10", function(x) 10^x),
                           labels = scales::trans_format("log10", scales::math_format(10^.x)))
}