<?php
// Native SQL parity on connection-local TEMPORARY tables only. No live table
// reads/writes, named locks, persistent DDL, listeners or application startup.
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
$sqls = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);
$db = new mysqli(getenv('WT_DB_HOST'), getenv('WT_DB_USER'), getenv('WT_DB_PASS'), getenv('WT_DB_NAME'), (int)(getenv('WT_DB_PORT') ?: 3306));
$prefix = 'perf_fixture_' . bin2hex(random_bytes(6)) . '_';
$names = ['whaletracker_log_players' => $prefix.'players', 'whaletracker_logs' => $prefix.'logs', 'whaletracker' => $prefix.'stats'];
function check($ok, $message) { if (!$ok) throw new RuntimeException($message); }
function selectRows($sql, $params = []) {
    global $db, $names;
    check(preg_match('/^\s*SELECT\b/i', $sql), 'fixture accepts SELECT only');
    $sql = strtr($sql, $names);
    check(!str_contains($sql, 'whaletracker'), 'unreplaced production table reference');
    $stmt = $db->prepare($sql);
    if ($params) $stmt->bind_param(str_repeat('i', count($params)), ...$params);
    $stmt->execute();
    return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}
function insertRow($table, $fields, $values) {
    global $db, $names;
    check(in_array($table, $names, true), 'fixture table only');
    $stmt = $db->prepare('INSERT INTO '.$table.' ('.$fields.') VALUES ('.implode(',',array_fill(0,count($values),'?')).')');
    $stmt->bind_param(str_repeat('s',count($values)), ...$values);
    $stmt->execute();
}
$logs = $names['whaletracker_logs']; $players = $names['whaletracker_log_players']; $stats = $names['whaletracker'];
$db->query("CREATE TEMPORARY TABLE $logs (log_id VARCHAR(64) PRIMARY KEY, map VARCHAR(64), gamemode VARCHAR(32), started_at BIGINT, ended_at BIGINT, duration BIGINT, player_count INT, created_at BIGINT, updated_at BIGINT, demo_filename VARCHAR(64))");
$db->query("CREATE TEMPORARY TABLE $players (log_id VARCHAR(64), steamid VARCHAR(64), personaname VARCHAR(64), best_streak BIGINT NULL, kills BIGINT NULL, PRIMARY KEY(log_id,steamid))");
$columns = explode(' ', 'kills assists playtime healing headshots backstabs damage_dealt damage_taken medic_drops total_ubers deaths airshots shots hits');
$db->query('CREATE TEMPORARY TABLE '.$stats.' ('.implode(',',array_map(fn($c) => "$c BIGINT NULL",$columns)).')');
$old = <<<'SQL'
SELECT lp.log_id,lp.steamid,lp.personaname,COALESCE(lp.best_streak,0) AS best_streak,COALESCE(lp.kills,0) AS kills,l.started_at
FROM whaletracker_log_players lp JOIN whaletracker_logs l ON l.log_id=lp.log_id
WHERE l.started_at>=? AND lp.log_id=(
 SELECT lp2.log_id FROM whaletracker_log_players lp2 JOIN whaletracker_logs l2 ON l2.log_id=lp2.log_id
 WHERE lp2.steamid=lp.steamid AND l2.started_at>=?
 ORDER BY COALESCE(lp2.best_streak,0) DESC,COALESCE(lp2.kills,0) DESC,l2.started_at DESC LIMIT 1)
ORDER BY COALESCE(lp.best_streak,0) DESC,COALESCE(lp.kills,0) DESC,l.started_at DESC LIMIT 3
SQL;
function seed($rows) {
    global $db, $logs, $players;
    $db->query("DELETE FROM $players"); $db->query("DELETE FROM $logs");
    foreach ($rows as [$log,$player,$streak,$kills,$started]) {
        insertRow($logs,'log_id,started_at,player_count',[$log,$started,1]);
        insertRow($players,'log_id,steamid,personaname,best_streak,kills',[$log,$player,$player,$streak,$kills]);
    }
}
$sets = [[], [['a','p1',null,null,100],['b','p2',0,1,101],['c','p3',-1,3,102]],
    [['a','p1',99,99,99],['b','p1',2,1,100],['c','p1',3,0,101],['d','p1',3,5,102],['e','p1',3,5,103],['f','p2',2,9,104],['g','p3',1,9,105],['h','p4',0,9,106],['i','p5',8,1,1000]]];
mt_srand(20261021);
for ($case=0; $case<25; $case++) {
    $rows=[]; $values=[null,0,1,3,9];
    for ($i=0;$i<70;$i++) $rows[]=[sprintf('l%03d',$i),'p'.mt_rand(0,11),$values[mt_rand(0,4)],$values[mt_rand(0,4)],$i+75];
    $sets[]=$rows;
}
foreach ($sets as $rows) {
    seed($rows);
    $before=selectRows($old,[100,100]); $after=selectRows($sqls['podium'],[100]);
    check($before==$after,'podium differential mismatch');
    check(count(array_unique(array_column($after,'steamid')))==count($after),'duplicate podium player');
}
seed([['z','p1',4,8,110],['a','p1',4,8,110],['b','p2',4,8,110]]);
$ties=selectRows($sqls['podium'],[100]);
check(array_column($ties,'log_id')==['a','b'],'deterministic exact tie rule');
$totals = <<<'SQL'
SELECT COUNT(*) AS total_players,COALESCE(SUM(kills),0) AS total_kills,COALESCE(SUM(assists),0) AS total_assists,
COALESCE(SUM(playtime),0) AS total_playtime,COALESCE(SUM(healing),0) AS total_healing,
COALESCE(SUM(headshots),0) AS total_headshots,COALESCE(SUM(backstabs),0) AS total_backstabs,
COALESCE(SUM(damage_dealt),0) AS total_damage,COALESCE(SUM(damage_taken),0) AS total_damage_taken,
COALESCE(SUM(medic_drops),0) AS total_drops,COALESCE(SUM(total_ubers),0) AS total_ubers_used FROM whaletracker
SQL;
$averages = <<<'SQL'
SELECT COUNT(*) AS eligible,AVG(CASE WHEN deaths>0 THEN kills/NULLIF(deaths,0) ELSE kills END) AS avg_kd,
AVG(damage_dealt) AS avg_damage,AVG(airshots) AS avg_airshots,AVG(healing) AS avg_healing,
AVG(CASE WHEN playtime>0 THEN damage_dealt/(playtime/60.0) END) AS avg_dpm,
AVG(CASE WHEN shots>0 THEN hits/shots END) AS avg_accuracy FROM whaletracker WHERE playtime>=18000
SQL;
$random=[]; $values=[null,0,5,17999,18000,25000];
for($i=0;$i<200;$i++) $random[]=array_map(fn($_)=>$values[mt_rand(0,5)],$columns);
foreach ([[],[array_fill(0,count($columns),null)],[array_fill(0,count($columns),0)],$random] as $rows) {
    $db->query("DELETE FROM $stats");
    foreach($rows as $row) insertRow($stats,implode(',',$columns),$row);
    $before=array_merge(selectRows($totals)[0],selectRows($averages)[0]);
    $after=selectRows($sqls['aggregate'])[0];
    foreach($before as $key=>$value) {
        check(($value===null)==($after[$key]===null),'aggregate NULL mismatch '.$key);
        check(abs((float)$value-(float)$after[$key])<0.000001,'aggregate numeric mismatch '.$key);
    }
}
seed([['old','p1',1,1,1],['new','p2',1,1,2],['empty','p3',1,1,3]]);
$db->query("UPDATE $logs SET player_count=0 WHERE log_id='empty'");
$latest=selectRows($sqls['logs'],[1,0]);
check(count($latest)==1 && $latest[0]['log_id']==='new','actual latest log query');
$db->query("DELETE FROM $logs"); check(selectRows($sqls['logs'],[1,0])==[],'empty latest query');
echo "MariaDB temporary fixture parity passed: 28 podium differential sets, exact ties, 4 aggregate sets, actual latest/empty queries; no persistent tables touched\n";
// Connection close drops all temporary tables automatically.
$db->close();
