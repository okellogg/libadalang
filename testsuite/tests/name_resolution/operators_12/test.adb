procedure Test is
   package Pkg is
      type R is private;
   private
      type R is null record;
   end Pkg;

   X : Pkg.R;
   B : Boolean := Pkg."=" (X, X);
   --% node.f_default_expr.f_name.p_referenced_decl()
begin
   null;
end Test;
