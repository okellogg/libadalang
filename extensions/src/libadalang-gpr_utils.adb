--
--  Copyright (C) 2014-2022, AdaCore
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Characters.Handling; use Ada.Characters.Handling;

with GNAT.Strings; use GNAT.Strings;

with GNATCOLL.Utils;
with GNATCOLL.VFS;        use GNATCOLL.VFS;
with GPR2.Containers;
with GPR2.Path_Name;
with GPR2.Project.Attribute;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Attribute_Index;
with GPR2.Project.Source;

package body Libadalang.GPR_Utils is

   -------------
   -- No_View --
   -------------

   function No_View (Tree : Any_Tree) return Any_View is
   begin
      case Tree.Kind is
      when GPR1_Kind =>
         return (Kind => GPR1_Kind, GPR1_Value => GPR1.No_Project);
      when GPR2_Kind =>
         return (Kind => GPR2_Kind, GPR2_Value => GPR2.Project.View.Undefined);
      end case;
   end No_View;

   ----------
   -- Root --
   ----------

   function Root (Self : Any_Tree) return Any_View is
   begin
      case Self.Kind is
      when GPR1_Kind =>
         return (Kind       => GPR1_Kind,
                 GPR1_Value => Self.GPR1_Value.Root_Project);
      when GPR2_Kind =>
         return (Kind       => GPR2_Kind,
                 GPR2_Value => Self.GPR2_Value.Root_Project);
      end case;
   end Root;

   -------------
   -- Iterate --
   -------------

   procedure Iterate
     (Self : Any_View; Process : access procedure (Self : Any_View)) is
   begin
      case Self.Kind is
      when GPR1_Kind =>
         declare
            use type GPR1.Project_Type;

            It : GPR1.Project_Iterator := Self.GPR1_Value.Start;
            P  : GPR1.Project_Type;
         begin
            loop
               P := GPR1.Current (It);
               exit when P = GPR1.No_Project;
               Process.all ((Kind => GPR1_Kind, GPR1_Value => P));
               GPR1.Next (It);
            end loop;
         end;

      when GPR2_Kind =>

         --  ``View`` is not in its own closure, so process it first

         Process.all (Self);

         --  If ``View`` is an aggregate project, also go through the
         --  aggregated projects.

         if Self.GPR2_Value.Kind in GPR2.Aggregate_Kind then
            for P of Self.GPR2_Value.Aggregated loop
               Iterate ((Kind => GPR2_Kind, GPR2_Value => P), Process);
            end loop;
         end if;

         --  If ``View`` extends another project, also go through that other
         --  project.
         --
         --  TODO (VB04-038)??? This may cause ``Iterate`` to process the same
         --  project multiple times: it is inefficient, but should not be a
         --  problem. Hopefully at some point GPR2 will provide an exhaustive
         --  iteration scheme which we will be able to use here as well.

         if Self.GPR2_Value.Is_Extending then
            Iterate
              ((Kind       => GPR2_Kind,
                GPR2_Value => Self.GPR2_Value.Extended_Root), Process);
         end if;

         for View of Self.GPR2_Value.Closure loop
            Process.all ((Kind => GPR2_Kind, GPR2_Value => View));
         end loop;
      end case;
   end Iterate;

   ----------------
   -- Object_Dir --
   ----------------

   function Object_Dir (Self : Any_View) return String is
   begin
      case Self.Kind is
      when GPR1_Kind =>
         return +Self.GPR1_Value.Object_Dir.Full_Name;
      when GPR2_Kind =>
         return String (Self.GPR2_Value.Object_Directory.Value);
      end case;
   end Object_Dir;

   -------------
   -- Indexes --
   -------------

   function Indexes
     (Self : Any_View; Attribute : Any_Attribute) return XString_Array is
   begin
      case Self.Kind is
      when GPR1_Kind =>
         declare
            Indexes : String_List :=
              Self.GPR1_Value.Attribute_Indexes (Attribute.GPR1_Value.all);
         begin
            return Result : XString_Array (Indexes'Range) do
               for I in Result'Range loop
                  Result (I) := To_XString (Indexes (I).all);
               end loop;
               GNATCOLL.Utils.Free (Indexes);
            end return;
         end;

      when GPR2_Kind =>
         declare
            Attrs : constant GPR2.Project.Attribute.Set.Object :=
              Self.GPR2_Value.Attributes (Attribute.GPR2_Value);
            I     : Positive := 1;
         begin
            return Result : XString_Array (1 .. Natural (Attrs.Length)) do
               for A of Attrs loop
                  Result (I) := To_XString (A.Index.Text);
                  I := I + 1;
               end loop;
            end return;
         end;
      end case;
   end Indexes;

   ------------
   -- Values --
   ------------

   function Values
     (Self      : Any_View;
      Attribute : Any_Attribute;
      Index     : String) return XString_Array is
   begin
      case Self.Kind is
      when GPR1_Kind =>
         declare
            Values : String_List_Access :=
              Self.GPR1_Value.Attribute_Value
                (Attribute.GPR1_Value.all, Index);
         begin
            if Values = null then
               return (1 .. 0 => <>);
            else
               return Result : XString_Array (Values.all'Range) do
                  for I in Result'Range loop
                     Result (I) := To_XString (Values.all (I).all);
                  end loop;
                  Free (Values);
               end return;
            end if;
         end;

      when GPR2_Kind =>
         declare
            Attr : constant GPR2.Project.Attribute.Object :=
              Self.GPR2_Value.Attribute
                (Name  => Attribute.GPR2_Value,
                 Index => GPR2.Project.Attribute_Index.Create (Index));
            Values : constant GPR2.Containers.Source_Value_List :=
              (if Attr.Is_Defined
               then Attr.Values
               else GPR2.Containers.Source_Value_Type_List.Empty_Vector);
         begin
            return Result : XString_Array (1 .. Natural (Values.Length)) do
               for I in Result'Range loop
                  Result (I) := To_XString (Values (I).Text);
               end loop;
            end return;
         end;
      end case;
   end Values;

   -------------------
   -- Is_Ada_Source --
   -------------------

   function Is_Ada_Source
     (Tree : Any_Tree; View : Any_View; Filename : String) return Boolean is
   begin
      case Tree.Kind is
      when GPR1_Kind =>
         declare
            use type GPR1.Project_Type;

            Path  : constant GNATCOLL.VFS.Virtual_File := Create (+Filename);
            Infos : constant GPR1.File_Info_Set :=
              Tree.GPR1_Value.Info_Set (Path);
         begin
            return
              (for some Info of Infos =>
               GPR1.File_Info (Info).Project (Root_If_Not_Found => False)
                 = View.GPR1_Value
               and then To_Lower (GPR1.File_Info (Info).Language) = "ada");
         end;

      when GPR2_Kind =>
         declare
            Path : constant GPR2.Path_Name.Object :=
              GPR2.Path_Name.Create_File
                (GPR2.Filename_Type (Filename), GPR2.Path_Name.No_Resolution);
            File : constant GPR2.Project.Source.Object :=
              View.GPR2_Value.Source (Path);
         begin
            return File.Is_Defined and then File.Is_Ada;
         end;
      end case;
   end Is_Ada_Source;

end Libadalang.GPR_Utils;