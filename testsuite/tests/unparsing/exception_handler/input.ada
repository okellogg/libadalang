procedure Foo
is
begin
   declare
      Bar : Baz;
   begin
      null;
      null;
   exception
      when Qux =>
         null;
      when
        Quxzxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      =>
         null;
      when Qux | Corgeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
      =>
         null;
      when Qux | Corge =>
         null;
      when
        Eeeeeeeeee :
          Quuuux
          | Cooorgeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
      =>
         null;
      when others =>
         null;
   end;
end Foo;
