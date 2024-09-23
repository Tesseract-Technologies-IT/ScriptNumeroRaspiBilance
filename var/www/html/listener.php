<?php 
/**
 * This script listens for UDP packets on a specified port and saves the received data to a log file.
 * 
 * @param string $params['interface'] The network interface to bind the socket to.
 * @param int $params['port'] The port number to bind the socket to.
 * @param string $params['log_file'] The file path to save the received data.
 * @param string $params['num_file'] The file path to save the extracted number from the received data.
 * 
 * @return void
 */


// comando per testare il listener.php : echo -n "20022DS-1.04.79.0033" | nc -u -b 255.255.255.255 20410
$params = require 'params-local.php'; // Include the params-local file

$socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP); // Create a UDP socket

if ($socket === false) {
    echo "socket_create() failed: reason: " . socket_strerror(socket_last_error()) . PHP_EOL;
    exit;
}

// Bind the socket to the specified network interface
socket_set_option($socket, SOL_SOCKET, SO_BINDTODEVICE, $params['interface']); 
// Enable broadcasting on the socket
socket_set_option($socket, SOL_SOCKET, SO_BROADCAST, 1); 
// Allow reusing the socket address
socket_set_option($socket, SOL_SOCKET, SO_REUSEADDR, 1); 
// Allow reusing the socket port
socket_set_option($socket, SOL_SOCKET, SO_REUSEPORT, 1); 

// Bind to all available interfaces
$ipAddress = "0.0.0.0"; 
// Bind the socket to the specified port
$bind = socket_bind($socket, $ipAddress, $params['port']); 
echo "Bind: " . $bind . PHP_EOL;
if ($bind) {
  echo "Sono in ascolto...";
  //
  file_put_contents(
    $params['log_file'],
    'started listening on port ['.$params['port'].'] at '.date('H:i').'.'.PHP_EOL,
    FILE_APPEND
  );
  while (1) {
    echo 'ciclo' . PHP_EOL;
    if ($src = @socket_recv($socket, $data, 9999, 0)) {
      echo 'Src: ' . $src . PHP_EOL;
      echo 'Raw: ' . $data . PHP_EOL;
      file_put_contents($params['log_file'], $data, FILE_APPEND);
      // Use a regular expression to search for a specific pattern in the data
      // The pattern is '-[0-9].\.*[0-9].\.([0-9].)\.'
      // - The '-' matches a hyphen character
      // - '[0-9]' matches any single digit
      // - '\.*' matches zero or more occurrences of a dot character
      // - '\.' matches a dot character
      // - '([0-9].)' captures a single digit within parentheses
      $match =  preg_match('/-[0-9].\.*[0-9].\.([0-9].)\./', $data, $matches);
      $ris = $matches[1];
      if (isset($ris[1])) {
        $ris = explode('.', $ris[1]);
        $ris = $ris[0];
        if ($ris) {
          echo 'serviamo il numero: ' . 
                $ris . 
                PHP_EOL;
          file_put_contents($params['num_file'], $ris);
        }
      } else {
        echo "Unexpected data format: " . 
              $data . 
              PHP_EOL;
      }
    }
    else {
      echo "socket_recv() failed; reason: " .
            socket_strerror(socket_last_error($socket)) .
            PHP_EOL;
    }
  }
} else {
  echo "socket_bind() failed: reason: " . 
        socket_strerror(socket_last_error($socket)) . 
        PHP_EOL;
}