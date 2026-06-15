<!DOCTYPE html>
<html>
  <head>
    <title>Image Gallery</title>
    <style>
      /* Add any styling you want for the gallery container and images here */
      .gallery-container {
        display: flex;
        flex-wrap: wrap;
        justify-content: center; /* Centers the images horizontally */
        align-items: center; /* Centers the images vertically */
        margin-left: 10%;
        margin-right: 10%;
      }
      .gallery-img {
        width: 15%;
        height: auto;
        object-fit: cover;
        margin: 10%;
      }
    </style>
  </head>
  <body>
    <div class="gallery-container"></div>

    <script src="./imageUrls.js"></script>
    <script>
      const galleryContainer = document.querySelector('.gallery-container');

      // Loop through the image URLs and create an image element for each
      imageUrls.forEach((url) => {
        const img = document.createElement('img');
        img.classList.add('gallery-img');
        img.setAttribute('src', url);
        galleryContainer.appendChild(img);
      });
    </script>
  </body>
</html>

