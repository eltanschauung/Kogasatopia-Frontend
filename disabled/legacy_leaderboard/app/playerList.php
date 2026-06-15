<?php
    echo '<div id="whaley" class="players-list" style="">';

    // Check if there is data to display
    if (!empty($result)) {
        echo '<table style="width=100%;">';

        foreach ($result as $key => $row) {
            $style = '';
            if (in_array("Respawning", $row)) {
                $style .= 'opacity: 0.3;';
            }
            if (in_array("RedTeam", $row)) {
                $style .= 'color: #fc9a9a;';
            }
            if (in_array("BlueTeam", $row)) {
                $style .= 'color: #9aceff;';
            }

            echo "<tr style=\"$style\">";
            foreach ($row as $cell) {
                // Use th for the first row to create header cells
                if ($key === 0 && (!(str_contains($cell, "Team")))) {
                    echo '<th>' . $cell . '</th>';
                } else {
                    if (array_key_exists($cell, $specialCharacterMap)) {
                        $imageName = $specialCharacterMap[$cell];
                        echo '<td>' . '<img src="' . $imageName . '" alt="" title="' . $cell . '">' . '</td>';
                    } else if (!(str_contains($cell, "Team"))) {
                        echo '<td>' . $cell . '</td>';
                    }
                }
            }
            echo '</tr>';
        }

        echo '</table>';
    }

    echo '</div>';
?>