var intervalId = window.setInterval(() => {
  fetch('./numCorr.txt')
    .then(response => {
      if (!response.ok) {
        throw new Error('Network response was not ok ' + response.statusText);
      }
      return response.text();
    })
    .then(data => {
      console.log("Successfully fetched data.", data);
      document.getElementById('numero').innerHTML = data;
    })
    .catch(error => {
      console.error("Failed to fetch data.", error);
      // Exit the loop
      clearInterval(intervalId);
    });
}, 1000);