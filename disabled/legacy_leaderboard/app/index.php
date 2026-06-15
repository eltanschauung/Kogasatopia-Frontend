<title>Kogasatopia</title>
<?php
// Specify the path to the text file
$filePath = '../playercount_widget/quickstats.txt';

$userAgent = $_SERVER['HTTP_USER_AGENT'];
$mobile = false;
if (strpos($userAgent, 'Mobile') !== false || strpos($userAgent, 'Android') !== false) {
    $mobile = true;
}

// Check if the file exists
if (file_exists($filePath)) {
    // Read the file into an array of lines
    $fileLines = file($filePath, FILE_IGNORE_NEW_LINES);

    // Initialize variables to store the extracted values
    $serverIP = $_SERVER['SERVER_ADDR']; // Set the server IP

    foreach ($fileLines as $line) {
       if (strpos($line, 'Hostname:') === 0) {
          // Extract the hostname value
          $serverName = trim(str_replace('Hostname:', '', $line));
	  //$serverName = 'The Youkai Pound | New Jersey | 18+ (Unless?)';
       } elseif (strpos($line, 'Port:') === 0) {
          // Extract the port value
          $serverPort = trim(str_replace('Port:', '', $line));
       } elseif (strpos($line, 'Player Count:') === 0) {
          // Extract the player count value
          $playerCount = trim(str_replace('Player Count:', '', $line));
       } elseif (strpos($line, 'Map Name:') === 0) {
          $mapName = str_replace('Map Name:', '', $line);
          $mapName = explode('.', str_replace('Map Name:', '', $line))[0];
       } elseif (preg_match('/^Player \d+: (.+)$/', $line, $matches)) {
          // Extract and store player names
          $players[] = $matches[1];
       }
    }

    include('../playercount_widget/touhouMaps.php');
    $specialCharacterMap = array(
        'Scout' => 'Scout.png',
        'Soldier' => 'Soldier.png',
        'Pyro' => 'Pyro.png',
        'Demoman' => 'Demoman.png',
        'Heavy' => 'Heavy.png',
        'Engineer' => 'Engineer.png',
        'Medic' => 'Medic.png',
        'Sniper' => 'Sniper.png',
        'Spy' => 'Spy.png',
        'Respawning' => ''
    );

    function strposa($haystack, $needles) {
        foreach ($needles as $needle) {
            if (strpos($haystack, $needle) !== false) {
                return true;
            }
        }
        return false;
    }

    function compare_score($a, $b) {
      return strnatcmp($b['Score'], $a['Score']);
    }

    function deleteColumn(array &$array, $columnIndex) {
        foreach ($array as &$row) {
            if (isset($row[$columnIndex])) {
                unset($row[$columnIndex]);
            }
        }
    }


    function updateTeamName(array $inputArray) {
        if (isset($inputArray[8])) {
            switch ($inputArray[8]) {
                case 1:
                    $inputArray[8] = "RedTeam";
                    break;
                case 2:
                    $inputArray[8] = "BlueTeam";
                    break;
                case 3:
                    $inputArray[8] = "SpectatorTeam";
                    break;
                // You can add more cases if needed
            }
        }
        return $inputArray;
    }

    if ($mobile) echo '<div class="server-name" style="font-size:32px;margin-bottom:4px;">' . $serverName . '</div>';
    else echo '<div class="server-name">' . $serverName . '</div>';

    echo '<div class="main-container">';
    echo '<div class="server-ip">';
    echo '<br>';
    echo '<a href="steam://connect/' . $serverIP . ':' . $serverPort .'">' . $serverIP . ':' . $serverPort . '</a> <img title="United States" src="https://bantculture.com/static/flags/bantflags/us.png"><img title="Kogasa" src="https://bantculture.com/static/flags/bantflags/kogasa.png">';
    echo '</div></div>';
    echo '<hr>'; // Add a 1px grey line

    echo '<div class="info-container">';

    echo '<div style="white-space: nowrap;" class="label">Otter Population:</div>';
    echo '<div class="value">' . $playerCount . '</div>';
    echo '</div></div>';

    $mapImageFileName = 'https://image.gametracker.com/images/maps/160x120/tf2/' . $mapName . '.jpg';
    $directory = '../playercount_widget'; // Relative path to the directory
    if (file_exists($directory . '/' . $mapName . '.jpg')) {
        $mapImageFileName = $directory . '/' . $mapName . '.jpg';
    }
    echo '<div class="info-container">';
    echo '<div class="label">Map:</div>';
    if (strposa($mapName, $importantMapNames)) {
        echo '<div class="value"><img src="../playercount_widget/chaos_emerald_green.png" title="Important Map" style="margin-right:2px;">' . $mapName . '</div>';
    } else {
        echo '<div class="value">' . $mapName . '</div>';
    }

    echo '</div>';
    // Create a separate div for the image with padding
    echo '<div class="image-container">';
    // Center the image using CSS styles
    echo '<div style="display: flex; justify-content: center;padding:0.2em;">';
    // Display the image with the generated filename
    if (!$mobile) {
        echo '<img style="border: 0.1em solid grey;width:160px;height:120px;"src="' . $mapImageFileName . '" alt="">';
    } else {
        echo '<img style="border: 0.1em solid grey;width:30%;height:auto;"src="' . $mapImageFileName . '" alt="">';
    }
    echo '</div>'; // Close the centered div
    echo '</div>';
    echo '<hr>'; // Add a 1px grey line

    if ($mobile) {
        $result[] = array(
        'Player', 'Class', 'Score', 'Kills', 'Deaths', 'Assists', 'Team', 'Time Connected'
        );
    } else {
        $result[] = array(
        'Player', 'Class', 'Killstreak', 'Score ▲', 'Kills', 'Deaths', 'Assists', 'Damage', 'Team', 'Time Connected'
        );
    }

    foreach ($players as $playerData) {
        $playerArray = explode('[X]', $playerData);
        if (!$mobile) {
        $result[] = array(
        'Player' => $playerArray[0],
        'Class' => $playerArray[1],
        'Killstreak' => $playerArray[2],
        'Score' => $playerArray[3],
        'Kills' => $playerArray[4],
        'Deaths' => $playerArray[5],
        'Assists' => $playerArray[6],
        'Damage' => $playerArray[7],
        'Team' => $playerArray[8],
        'Time Connected' => $playerArray[9]
        );
        } else {
        $result[] = array(
        'Player' => $playerArray[0],
        'Class' => $playerArray[1],
        'Score' => $playerArray[3],
        'Kills' => $playerArray[4],
        'Deaths' => $playerArray[5],
        'Assists' => $playerArray[6],
        'Team' => $playerArray[7],
        'Time Connected' => $playerArray[8]
        );
        }
    }

    $header = array_shift($result);
    usort($result, 'compare_score');
    array_unshift($result, $header);

    echo '<div class="flex-container">';
    include('playerList.php');
    if (!$mobile) {
    include('whaleSchools.php');
    }
    echo '</div>';
    echo '</div>';

    echo '<div id="footer" class="flex-container">';
    echo '<img src="/stats/assets/wholesome2.gif" alt="vehicles" />';
    echo '<img src="/stats/assets/whaletracker_logo.png" alt="whaley" />';
    echo '</div>';
}
?>

<style>
    body {
      //overflow: hidden;
      margin: 0.5em 0px;
      width: 100vw; /* 100% of the viewport width */
      min-height: 100vh; /* At least 100% of the viewport height */
      background-repeat: no-repeat;
      font-family: Open Sans,Helvetica Neue,Helvetica,Arial,sans-serif;
      color: white;
      line-height: 1.2em;
      background-image: url('/stats/assets/background_product_pro.jpg');
      background-color:#3d3730;
    }
    .server-name {
      font-size: 22px;
      font-weight: bold;
      text-align: center;
    }
    a {
      text-decoration: none;
      color: #ee6c3b;
      font-size: 1.20em;
    }
    .main-container {
      text-align: center;
      line-height: 0.55em;
    }
    .info-container {
      font-size: 16px;
      text-align:center;
      display: flex;
      margin-left: 40%;
      margin-right: 40%;
    }
    .label {
      flex: 1;
      font-weight: bold;
      color: white;
    }
    .label2 {
      font-weight: bold;
      color: white;
    }
    .value {
      flex: 1;
      color: white;
    }
    .value2 {
      flex: 1;
      color: white;
    }
    .players-list {
      background-color: rgba(26, 24, 21, 0.85);
      overflow: auto;
      margin-left: 4px;
      margin-right: 4px;
      border: 0.2em solid grey;
    }
    .server-ip img {
      padding: 1px;
    }
    .flex-container {
        display: flex;
        justify-content: center;
        height: 60vh;
    }
    #footer img {
        max-height: 6em;
        padding: 20px 10px 0px 10px;
    }
    #footer {
        display: flex;
        justify-content: space-between;
    }
    li {
      margin-top: 2px;
    }
    table {
      border-collapse: separate;
      margin-top: 10px;
      border-spacing: 40px 0;
    }
    td {
      padding: 10px 0;
      text-align: center;
    }
</style>
