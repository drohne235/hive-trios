
fl

\ _words ( cstr -- ) prints the words in the forth dictionary starting with cstr, 0 prints all
: _words lastnfa 
begin
	2dup swap dup if npfx else 2drop -1 then
	if dup .strname space then 
    nfa>next dup 0=
until 2drop cr ;

\ words ( -- ) prints the words in the forth dictionary, if the pad has another string following, with that prefix
: words parsenw _xwords ;

: t1 1000 0 do i . loop ;
: t2 1000 0 do ." test " loop ;
