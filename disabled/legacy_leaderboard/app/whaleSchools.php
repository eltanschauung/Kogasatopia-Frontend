<?php
    $input_file = '../playercount_widget/mapstats_output.txt';
    $lines = file($input_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

    // Display the numbered list of data from the file
    echo '<div class="players-list" style="display: inline-block;white-space: nowrap;">';
    echo '<div style="margin:10px 8px;" class="label">Whale schools:</div>';
    echo '<div class="value2" style="text-align:center;"><ol>';

    foreach ($lines as $line) {
        $line = trim($line); // Remove leading/trailing whitespace
        if (strposa($line, $importantMapNames)) {
            echo '<li><img src="../playercount_widget/chaos_emerald_green.png" title="Important Map" style="margin-right:2px;">' . htmlspecialchars($line) . '</li>';
        } else {
            echo '<li>' . htmlspecialchars($line) . '</li>'; // For other cases
        }
    }
    echo '</div>';
    echo '</div>';
?>
