library(FlowSOM)
library(pheatmap)
library(magick)
library(cytofkit) # Can't get fastphenograph to work

FlowSom <- function(dat, num_mc = 30) {
  input <- FlowSOM::ReadInput(as.matrix(dat))
  som <- FlowSOM::BuildSOM(input)
  mc <- FlowSOM::metaClustering_consensus(som$map$codes, k = num_mc)
  mc_cells <- FlowSOM::GetMetaclusters(som, mc)
  return(mc_cells)
}

PhenoGraph <- function(dat, k = 30) {
  clust_percell <- cytofkit::cytof_cluster(xdata = as.matrix(dat), 
                                           method = "Rphenograph", 
                                           Rphenograph_k = k)
  return(clust_percell)
}

MakePlots <- function(dat, num_iter = 50, num_mc = num_mc, pg_k = 30, method = "FlowSOM") {
  for(i in seq(num_iter)) {
    
    if(method == "FlowSOM") {
      mc_cells <- FlowSom(dat, num_mc = num_mc)
    } else {
      mc_cells <- PhenoGraph(dat, k = pg_k)
    }
    
    clust <- unique(mc_cells)
    
    tmp <- bind_cols(umap, cluster = mc_cells)
    
    clust_cent <- lapply(clust, function(i) {
      result <- dplyr::filter(tmp, mc_cells == i) %>% apply(., 2, median)
      return(result)
    }) %>% do.call(rbind, .) %>% as_tibble()
    
    ggplot() + 
      geom_point(data = tmp, 
                 aes(x = umap1, y = umap2), 
                 color = "black", 
                 alpha = 0.9) +
      geom_point(data = clust_cent, 
                 aes(x = umap1, y = umap2), 
                 color = "yellow", 
                 size = 3)
    ggsave(paste0("plot", i, ".png"))
  }
}

ImageDistance <- function(im1, im2, metric = "MSE") {
  return(magick::image_compare_dist(image = im1, reference_image = im2, metric = 'RMSE')$distortion)
}

MakeGif <- function(fps = 5, outfile = "ordered_images.gif") {
  files <- list.files()
  
  # Create a list to store the images, make them smaller
  images <- lapply(files, function(i) {
    result <- image_read(i) %>% image_scale('10%')
  })
  
  # Create an empty matrix to store the distances
  n <- length(files)
  distances <- matrix(0, nrow = n, ncol = n)
  
  # Calculate the pairwise distances between the rows of the matrix
  #count <- 0
  for (i in 1:n) {
    #count <- count + 1
    #print(count)
    for (j in 1:n) {
      distances[i, j] <- ImageDistance(images[[i]], images[[j]])
    }
  }
  
  rownames(distances) <- colnames(distances) <- files
  
  # Clustered heatmap
  ph <- pheatmap::pheatmap(distances)
  
  # New order
  imgs <- files[ph$tree_row$order]
  imgs <- paste0(getwd(), "/", imgs)
  
  # Read in files in this order
  img_list <- lapply(imgs, function(i) {
    magick::image_read(i) %>% magick::image_scale('50%')
  })
  
  ## join the images together
  img_joined <- image_join(img_list)
  
  ## animate at 2 frames per second
  img_animated <- image_animate(img_joined, fps)
  
  ## Set outfile
  outfile <- paste0(getwd(), "/", outfile)
  
  ## save to disk
  image_write(image = img_animated,
              path = outfile)
} 
