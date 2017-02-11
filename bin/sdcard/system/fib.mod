
: mod:fib ;

\ ( n -- f ) berechnet die nte fibonacci-zahl
: fib 
  0 1 rot 0 do over + swap loop drop ;

\ benchmark über n fibonacci-zahlen
: fibo-bench
  1+ 1 do
    i ." fibo(" . ." ) = "
    i cnt COG@ swap fib cnt COG@ swap .
    swap - ." , ticks : " . 
    cr 
  loop ;
  
decimal 40 fibo-bench hex 




  