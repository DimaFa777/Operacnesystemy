#!/bin/bash
# Operačné systémy — Zadanie 1: loganalyza.sh
# Doplň jednotlivé príkazy. Každý číta prístupový log a píše presný výstup na stdout.
#
# Formát riadka logu:
#   IP - - [dd/Mon/yyyy:HH:MM:SS +0100] "METODA CESTA PROTO" STATUS VELKOST
#
# Spúšťanie:  ./loganalyza.sh <prikaz> <argumenty...>
# Príkazy a ich presný výstup sú opísané v zadaní (PDF).

cmd="${1:-}"
log="${2:-}"

case "$cmd" in

  pocet)
    # Vypíš jedno číslo: celkový počet riadkov v logu.
    awk 'END { print NR + 0 }' "$log"
    ;;

  kody)
    # Pre každý stavový kód vypíš riadok "KOD POCET", zoradené podľa kódu vzostupne.
    awk '{ count[$9]++ } END { for (code in count) print code, count[code] }' "$log" | LC_ALL=C sort -k1,1n
    ;;

  top)
    # top <log> <N>: N IP adries s najviac požiadavkami, riadok "POCET IP",
    # zoradené podľa počtu zostupne, pri zhode podľa IP vzostupne.
    n="${3:-}"
    awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' "$log" | LC_ALL=C sort -k1,1nr -k2,2 | head -n "$n"
    ;;

  chyby)
    # Vypíš jedno celé číslo: percento požiadaviek so stavom 400 a vyšším,
    # zaokrúhlené podľa vzorca  (100*chyby + spolu/2) / spolu.
    awk '
      $9 + 0 >= 400 { errors++ }
      { total++ }
      END {
        if (total == 0) print 0
        else print int((100 * errors + int(total / 2)) / total)
      }
    ' "$log"
    ;;

  okno)
    # okno <log> <IP>: vypíš "OD DO" (najskorší a najneskorší čas HH:MM:SS tej IP).
    # Ak IP v logu nie je, nevypíš nič a skonči s nenulovým návratovým kódom (exit 1).
    ip="${3:-}"
    awk -v target="$ip" '
      $1 == target {
        time_str = substr($4, index($4, ":") + 1)
        if (!found || time_str < min_time) min_time = time_str
        if (!found || time_str > max_time) max_time = time_str
        found = 1
      }
      END {
        if (!found) exit 1
        print min_time, max_time
      }
    ' "$log"
    ;;

  detektor)
    # detektor <log> <PRAH>: IP s počtom chybových požiadaviek (stav >=400) väčším
    # ako PRAH, riadok "POCET IP", zoradené zostupne, pri zhode IP vzostupne.
    prah="${3:-}"
    awk -v limit="$prah" '
      $9 + 0 >= 400 { errors[$1]++ }
      END {
        for (ip in errors) {
          if (errors[ip] > limit + 0) print errors[ip], ip
        }
      }
    ' "$log" | LC_ALL=C sort -k1,1nr -k2,2
    ;;

  klasifikuj)
    # Nájdi najaktívnejšiu IP (pri zhode menšia IP) a vypíš "TYP IP".
    # TYP urči podľa pravidla v zadaní: hadanie_hesiel / skenovanie / ziadny.
    awk '
      {
        ip = $1
        path = $7
        status = $9 + 0
        total[ip]++
        if (status >= 400) errors[ip]++
        if (!seen[ip, path]++) paths[ip]++
      }
      END {
        if (NR == 0) exit 0
        top_ip = ""
        max_count = -1
        for (ip in total) {
          if (total[ip] > max_count || (total[ip] == max_count && ip < top_ip)) {
            max_count = total[ip]
            top_ip = ip
          }
        }
        req_count = total[top_ip]
        err_count = errors[top_ip] + 0
        unique_paths = paths[top_ip] + 0
        error_rate = err_count / req_count

        if (req_count >= 50 && error_rate >= 0.7 && unique_paths <= 3) {
          print "hadanie_hesiel", top_ip
        } else if (req_count >= 50 && error_rate >= 0.7 && unique_paths >= 6) {
          print "skenovanie", top_ip
        } else {
          print "ziadny", top_ip
        }
      }
    ' "$log"
    ;;

  *)
    echo "neznamy prikaz: $cmd" >&2
    exit 2
    ;;
esac
