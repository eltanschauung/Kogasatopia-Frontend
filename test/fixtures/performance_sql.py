"""Execute actual Elixir-produced SQL on isolated SQLite fixtures, never a server DB.

SQLite exercises the relational/window semantics. MySQL production planning and
timings are separately parent-measured; this is not a production benchmark.
"""
import random
import sqlite3
import sys

window, aggregate, logs_sql = sys.argv[1:]
db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE whaletracker_logs(log_id TEXT PRIMARY KEY, started_at INTEGER, player_count INTEGER, map TEXT, gamemode TEXT, ended_at INTEGER, duration INTEGER, created_at INTEGER, updated_at INTEGER, demo_filename TEXT)")
db.execute("CREATE TABLE whaletracker_log_players(log_id TEXT, steamid TEXT, personaname TEXT, best_streak INTEGER, kills INTEGER, PRIMARY KEY(log_id,steamid))")
old = """
SELECT lp.log_id,lp.steamid,lp.personaname,COALESCE(lp.best_streak,0),COALESCE(lp.kills,0),l.started_at
FROM whaletracker_log_players lp JOIN whaletracker_logs l ON l.log_id=lp.log_id
WHERE l.started_at>=? AND lp.log_id=(
 SELECT lp2.log_id FROM whaletracker_log_players lp2 JOIN whaletracker_logs l2 ON l2.log_id=lp2.log_id
 WHERE lp2.steamid=lp.steamid AND l2.started_at>=?
 ORDER BY COALESCE(lp2.best_streak,0) DESC,COALESCE(lp2.kills,0) DESC,l2.started_at DESC LIMIT 1)
ORDER BY COALESCE(lp.best_streak,0) DESC,COALESCE(lp.kills,0) DESC,l.started_at DESC LIMIT 3
"""

def seed(rows):
    db.execute("DELETE FROM whaletracker_log_players")
    db.execute("DELETE FROM whaletracker_logs")
    for log, player, streak, kills, started in rows:
        db.execute("INSERT OR IGNORE INTO whaletracker_logs(log_id,started_at,player_count) VALUES (?,?,1)", (log, started))
        db.execute("INSERT INTO whaletracker_log_players VALUES (?,?,?,?,?)", (log,player,player,streak,kills))

def parity(rows, cutoff=100):
    seed(rows)
    before = db.execute(old, (cutoff,cutoff)).fetchall()
    after = db.execute(window, (cutoff,)).fetchall()
    assert after == before, (before, after)
    assert len({row[1] for row in after}) == len(after)
    # Output filtering remains after LIMIT 3, just as in the original Elixir.
    assert [r for r in after if r[3] > 0] == [r for r in before if r[3] > 0]

parity([])
parity([("a","p1",None,None,100), ("b","p2",0,1,101), ("c","p3",-1,3,102)])
parity([("a","p1",99,99,99), ("b","p1",2,1,100), ("c","p1",3,0,101),
        ("d","p1",3,5,102), ("e","p1",3,5,103), ("f","p2",2,9,104),
        ("g","p3",1,9,105), ("h","p4",0,9,106), ("i","p5",8,1,1000)])
rng = random.Random(20261021)
for case in range(100):
    parity([(f"l{i:03}", f"p{rng.randrange(12)}", rng.choice([None,0,1,3,9]),
             rng.choice([None,0,1,5]), i+75) for i in range(70)])
# Previously unspecified exact ties: stable ascending log_id within a player,
# stable steamid between players; all defined score/kills/time ordering is intact.
seed([("z","p1",4,8,110), ("a","p1",4,8,110), ("b","p2",4,8,110)])
assert [r[:2] for r in db.execute(window,(100,))] == [("a","p1"),("b","p2")]

columns = "kills assists playtime healing headshots backstabs damage_dealt damage_taken medic_drops total_ubers deaths airshots shots hits".split()
db.execute("CREATE TABLE whaletracker(" + ",".join(c+" REAL" for c in columns) + ")")
totals = """SELECT COUNT(*) AS total_players,
COALESCE(SUM(kills),0) AS total_kills,COALESCE(SUM(assists),0) AS total_assists,
COALESCE(SUM(playtime),0) AS total_playtime,COALESCE(SUM(healing),0) AS total_healing,
COALESCE(SUM(headshots),0) AS total_headshots,COALESCE(SUM(backstabs),0) AS total_backstabs,
COALESCE(SUM(damage_dealt),0) AS total_damage,COALESCE(SUM(damage_taken),0) AS total_damage_taken,
COALESCE(SUM(medic_drops),0) AS total_drops,COALESCE(SUM(total_ubers),0) AS total_ubers_used FROM whaletracker"""
averages = """SELECT COUNT(*) AS eligible,
AVG(CASE WHEN deaths>0 THEN kills/NULLIF(deaths,0) ELSE kills END) AS avg_kd,
AVG(damage_dealt) AS avg_damage, AVG(airshots) AS avg_airshots, AVG(healing) AS avg_healing,
AVG(CASE WHEN playtime>0 THEN damage_dealt/(playtime/60.0) END) AS avg_dpm,
AVG(CASE WHEN shots>0 THEN hits/shots END) AS avg_accuracy FROM whaletracker WHERE playtime>=18000"""

def mapped(sql):
    cur = db.execute(sql)
    return dict(zip([c[0] for c in cur.description], cur.fetchone()))

for rows in [[], [[None]*len(columns)], [[0]*len(columns)],
             [[rng.choice([None,0,5,17999,18000,25000]) for _ in columns] for _ in range(200)]]:
    db.execute("DELETE FROM whaletracker")
    db.executemany("INSERT INTO whaletracker VALUES ("+",".join("?" for _ in columns)+")", rows)
    assert mapped(aggregate) == dict(mapped(totals), **mapped(averages))

# Latest-row mapping query selection is shared with pagination; a count has no
# bearing on the selected current row. Fixture checks cutoff/zero-player cases.
db.execute("DELETE FROM whaletracker_logs")
db.executemany("INSERT INTO whaletracker_logs(log_id,started_at,player_count) VALUES (?,?,?)", [("old",1,1),("new",2,1),("empty",3,0)])
assert db.execute(logs_sql,(1,0)).fetchone()[0] == "new"
db.execute("DELETE FROM whaletracker_logs")
assert db.execute(logs_sql,(1,0)).fetchall() == []
print("fixture parity passed: 103 podium differential sets, exact ties, 4 aggregate sets, latest selection")
