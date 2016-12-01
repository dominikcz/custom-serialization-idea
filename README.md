# custom serialization idea for mORMot
This simple program is my attempt to show problems with current state of serialization/deserialization in mORMot framework.

Writing custom serializers requires lots of code duplication from synCommons.pas and or mORMot.pas. Even if you want to change the way serialization/deserialization works for only few types you have to rewrite almost everything.

Main idea:
* register separate readers and writers for every type and use them from registry. This way user can fine tune just the parts he needs, without code duplication. 
* no more rigid "case aValue.Kind of..."
* no more "if aValue.TypeInfo = TypeInfo(xxxxx) then..."

In this example program:
* I use TJSONSerializer.RegisterCustomSerializer() to implement general custom serilizer (different from default one from Synopse). It allows serialization of >= public fields and propertes, as well as use of attributes to fruther tune serialization/deserialization process
* then register few simple type parsers with TSerializer.RegisterCustomType() - it's not complete list, it's just ment to show the idea
* since it's only prototype of idea I've implemented only writers

What to do next?
Since it was meant as a quick and dirty prototype I use generics massively. I'd like this code to be implemented in core Synopse and as that it should be changed to more general and speed optimised version.

For more details see http://synopse.info/forum/viewtopic.php?id=3664
