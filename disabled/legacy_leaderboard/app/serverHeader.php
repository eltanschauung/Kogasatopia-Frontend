<?php
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
        echo '<img style="border: 0.1em solid grey;"src="' . $mapImageFileName . '" alt="">';
    } else {
        echo '<img style="border: 0.1em solid grey;width:30%;height:auto;"src="' . $mapImageFileName . '" alt="">';
    }
    echo '</div>'; // Close the centered div
    echo '</div>';
    echo '<hr>'; // Add a 1px grey line
?>