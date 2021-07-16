create or replace procedure SRC_CODE_SCAN( I_SRC_NAME       in varchar2 
                                         , I_SRC_OWNER      in varchar2 := null
                                         , I_SRC_TYPE       in varchar2 := 'PACKAGE BODY'
                                         ) is
/***************************************************************************************************************************

    This procedure scans the specified source code char by char.
    There is a function what sets the char is within a comment or string delimited by quote or a word.
    We can use it to manipulate the source.
    
    This example change the case of the words what are specified in WORDS table.
    I used it to change case conventions from mine to an other.

    History of changes
    yyyy.mm.dd | Version | Author   | Changes
    -----------+---------+----------+-----------------------------------------------------------------------
    2021.07.15 |  1.0    | Tothf    | Created
               |         |          |
***************************************************************************************************************************/

    V_SRC_NAME          varchar2( 200 )   := upper( trim( I_SRC_NAME ) );
    V_SRC_OWNER         varchar2( 200 )   := nvl( upper( trim( I_SRC_OWNER ) ), SYS_CONTEXT( 'USERENV', 'CURRENT_SCHEMA' ) );
    V_SRC_TYPE          varchar2( 200 )   := upper( trim( I_SRC_TYPE ) );
            
    V_POS               integer;
    V_LEN               integer;
    V_ORIG_LINE         varchar2( 4000 );
    V_NEW_LINE          varchar2( 4000 );
    V_CHAR              char    (    1 );
            
    V_IN_COMMENT1       boolean  := false;    -- within /*  */
    V_IN_COMMENT2       boolean  := false;    -- within --
    V_IN_STRING1        boolean  := false;    -- within ' '
    V_IN_STRING2        boolean  := false;    -- within q'[ ]'
    V_IN_SORC           boolean  := false;    -- within String OR Comment
    V_IN_WORD           boolean  := false;    -- within a sequence of alphanum characters

    V_LAST_WORD         varchar2( 4000 );
        
    C_ALPHANUM          varchar2( 200 ) := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';
    C_COMM_1_START      varchar2(   2 ) := '/*';
    C_COMM_1_END        varchar2(   2 ) := '*/';   
    C_COMM_2_START      varchar2(   2 ) := '--';
    C_STRING_1_START    varchar2(   1 ) := '''';
    C_STRING_1_END      varchar2(   1 ) := '''';
    C_STRING_2_START    varchar2(   3 ) := 'q''[';
    C_STRING_2_END      varchar2(   2 ) := ''']';
    
    -------------------------------------------------------------------------------------
    procedure CHK_POS is
    begin

        if not V_IN_SORC and substr( V_ORIG_LINE, V_POS, length( C_COMM_1_START ) ) = C_COMM_1_START then

            V_IN_SORC     := true;
            V_IN_COMMENT1 := true;
            V_POS         := V_POS + length( C_COMM_1_START );
            V_NEW_LINE    := V_NEW_LINE || C_COMM_1_START;

        elsif not V_IN_SORC and substr( V_ORIG_LINE, V_POS, length( C_COMM_2_START ) ) = C_COMM_2_START then

            V_IN_SORC     := true;
            V_IN_COMMENT2 := true;
            V_POS         := V_POS + length( C_COMM_2_START );
            V_NEW_LINE    := V_NEW_LINE || C_COMM_2_START;

        elsif not V_IN_SORC and substr( V_ORIG_LINE, V_POS, length( C_STRING_1_START ) ) = C_STRING_1_START then

            V_IN_SORC     := true;
            V_IN_STRING1  := true;
            V_POS         := V_POS + length( C_STRING_1_START );
            V_NEW_LINE    := V_NEW_LINE || C_STRING_1_START;
        
        elsif not V_IN_SORC and substr( V_ORIG_LINE, V_POS, length( C_STRING_2_START ) ) = C_STRING_2_START then

            V_IN_SORC     := true;
            V_IN_STRING2  := true;
            V_POS         := V_POS + length( C_STRING_2_START );
            V_NEW_LINE    := V_NEW_LINE || C_STRING_2_START;
        
        elsif V_IN_COMMENT1 and substr( V_ORIG_LINE, V_POS, length( C_COMM_1_END ) ) = C_COMM_1_END then

            V_IN_SORC     := false;
            V_IN_COMMENT1 := false;
            V_POS         := V_POS + length( C_COMM_1_END );
            V_NEW_LINE    := V_NEW_LINE || C_COMM_1_END;

        elsif V_IN_STRING1 and substr( V_ORIG_LINE, V_POS, length( C_STRING_1_END ) ) = C_STRING_1_END then

            V_IN_SORC     := false;
            V_IN_STRING1  := false;
            V_POS         := V_POS + length( C_STRING_1_END );
            V_NEW_LINE    := V_NEW_LINE || C_STRING_1_END;

        elsif V_IN_STRING2 and substr( V_ORIG_LINE, V_POS, length( C_STRING_2_END ) ) = C_STRING_2_END then

            V_IN_SORC     := false;
            V_IN_STRING2  := false;
            V_POS         := V_POS + length( C_STRING_2_END );
            V_NEW_LINE    := V_NEW_LINE || C_STRING_2_END;

        elsif instr( C_ALPHANUM, substr( V_ORIG_LINE, V_POS, 1 ) ) > 0 then

            V_IN_WORD     := true;
            V_LAST_WORD   := V_LAST_WORD || substr( V_ORIG_LINE, V_POS, 1 );
            V_NEW_LINE    := V_NEW_LINE  || substr( V_ORIG_LINE, V_POS, 1 );
            V_POS         := V_POS + 1;
            if V_POS > V_LEN then
                V_POS     := V_POS + 1;
                V_IN_WORD := false;
            end if;    

        else

            V_IN_WORD     := false;
            V_NEW_LINE    := V_NEW_LINE  || substr( V_ORIG_LINE, V_POS, 1 );
            V_POS         := V_POS + 1;
        
        end if;    

    end;
    
    -------------------------------------------------------------------------------------

    function CHANGE_WORD( I_WORD in varchar2 ) return varchar2 is
    begin
        for L_F in ( select * from WORDS where WORD = I_WORD )
        loop
            if L_F.ULC = 'C' then

                return initcap( I_WORD );

            elsif L_F.ULC = 'U' then

                return upper( I_WORD );

            elsif L_F.ULC = 'L' then

                return lower( I_WORD );
                
            end if;
            
        end loop;

        return I_WORD;

     end;   

    -------------------------------------------------------------------------------------
    
begin
    for L in ( select * 
                 from all_source 
                where owner = V_SRC_OWNER 
                  and name  = V_SRC_NAME
                  and type  = V_SRC_TYPE
                order by line 
             )
    loop

        V_ORIG_LINE := rtrim( rtrim( L.text, chr(10) ), chr(13) );
        V_POS       := 1;
        V_LEN       := nvl( length( V_ORIG_LINE ), 0 );
        V_NEW_LINE  := '';
        V_LAST_WORD := '';

        loop

            exit when V_POS > V_LEN;
                        
            CHK_POS;

            /* ******************************************************************************** */
            --  start of manipulation
            if V_IN_SORC then  -- do not touch words within remarks or strings

                V_LAST_WORD := '';
            
            elsif not V_IN_SORC and not V_IN_WORD and V_LAST_WORD is not null then
                -- we are not inside remark nor string but after a word

                V_NEW_LINE := substr( V_NEW_LINE, 1,  V_POS - 1 - length( V_LAST_WORD ) - 1 ) || CHANGE_WORD( V_LAST_WORD ) || substr( V_NEW_LINE, V_POS - 1, 1 );
                
                V_LAST_WORD := '';
                
            end if;
            --  end of manipulation
            /* ******************************************************************************** */
                        
        end loop;        
        
        if V_IN_COMMENT2 then

            V_IN_SORC     := false;
            V_IN_COMMENT2 := false;

        end if;    

        dbms_output.put_line( V_NEW_LINE );

    end loop;

end;
/
