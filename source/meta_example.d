/++
メタプログラミング

メタプログラミングに出てくるイディオム等についてまとめます。

Source: $(LINK_TO_SRC source/_meta_example.d)
+/
module meta_example;

/++
モジュールの定義一覧を取得する例です。

`__traits(allMembers, モジュール名)`と書きます。
+/
@safe unittest
{
    import std.stdio;

    alias StdMembers = __traits(allMembers, std.stdio);

    static assert(StdMembers.length > 0);
}

/++
任意のモジュール名から定義一覧を取得するイディオムです。

モジュールの参照を`mixin`と`std.meta.Alias`を使って取得します。
+/
@safe unittest
{
    template Module(string moduleName)
    {
        mixin("private import " ~ moduleName ~ ";");
        import std.meta : Alias;

        private alias mod = Alias!(mixin(moduleName));

        alias ModuleMembers = __traits(allMembers, mod);
    }

    alias MetaMembers = Module!(__MODULE__).ModuleMembers;
    static assert(MetaMembers.length > 0);

    alias ArrayMembers = Module!"array_example".ModuleMembers;
    static assert(ArrayMembers.length > 0);
}

/++
実際にコンパイルできるかどうか確認するイディオムです。

D言語のコード片が実際にコンパイルできる場合にはtrueに、そうでない場合はfalseに評価されます。
この強力なイディオムのやり方は2種類あって、`is(typeof(...))`を使用する方法と、`__traits(compiles, ...)`を使用する方法があります。
どちらでも効果はほぼ同じですが、やや`is(typeof(...))`のほうがチェックが緩いです。過去dmdへ多大な貢献をされた[9rnsrさんの記事](https://qiita.com/9rnsr/items/5e3e434ea8719fbeea82)で解説されています。

なお、このイディオムはきわめて強力な一方、実際にコンパイルできるかどうか、コンパイラが実際にコンパイルを試行して確かめる必要があるため、コンパイル速度的にはやや不利です。
そのためかどうなのか、std.rangeのisInputRangeなどは、[過去この方法で実装されていた](https://github.com/dlang/phobos/blob/c4f1c43366c79f4ff9ddfadbc0a8c943e0cb5c94/std/range.d#L528)こともありますが、[今は違います](https://github.com/dlang/phobos/blob/d29ebfe6ec0fd3879513e0f8a533b234f3d101e1/std/range/primitives.d#L171)。
+/
@safe unittest
{
    struct S1
    {
        void foo(){ }
    }
    struct S2
    {
        void foo(int x){ }
        void bar(int x){ }
    }

    // 引数のないfooメソッドのある型Tを判定する
    // こっちは is(typeof(...)) の方法で判定する
    enum hasFoo(T) = is(typeof({
        // 変数が定義可能
        T val;
        // fooメソッドの呼び出しができる
        val.foo();
    }));

    // int型の引数を指定するbarメソッドのある型Tを判定する
    // こっちは __traits(compiles, ...) の方法で判定する
    enum hasBar(T) = __traits(compiles, {
        // 変数が定義可能
        T val;
        // int型の引数でbarメソッドの呼び出しができる
        val.bar(1);
    });

    // S1にはfooメソッドがある
    static assert(hasFoo!S1);
    // S1にはbarメソッドがない
    static assert(!hasBar!S1);
    // S2にはfooメソッドはあるが、int型の引数が必要
    static assert(!hasFoo!S2);
    // S2にはint型の引数が必要なbarメソッドがある
    static assert(hasBar!S2);

    // もちろん、直接 static if や、 static assert で使うこともできます
    static assert(!__traits(compiles, {
        S1 s1;
        S2 s2;
        // S1とS2の足し算はできるか？
        auto s3 = s1 + s2; // →できないのでfalse
    }));
}

/++
一度特殊化されたテンプレートの型から、特殊化前のテンプレートと引数を取得する例です。
+/
unittest
{
    template MyTemplate(T, U)
    {
        alias Key = T;
        alias Value = U;
    }

    alias MyT = MyTemplate!(int, string);

    // 特殊化に使ったパラメーターを得るには TemplateArgsOf を利用します
    import std.traits : TemplateArgsOf;

    alias Args = TemplateArgsOf!MyT;
    static assert(is(Args[0] == int));
    static assert(is(Args[1] == string));

    // 特殊化前のテンプレートそのものを取り出すには TemplateOf を利用します
    import std.traits : TemplateOf;

    alias Temp = TemplateOf!MyT;
    static assert(__traits(isSame, Temp, MyTemplate));
}

/++
ある型が、特定のテンプレートを特殊化したものかどうかを判定する例です。
+/
unittest
{
    template MyTemplate(T, U)
    {
        alias Key = T;
        alias Value = U;
    }

    alias MyT1 = MyTemplate!(int, string);
    alias MyT2 = MyTemplate!(string, string);

    // 判定するには isInstanceOf を利用します
    import std.traits : isInstanceOf;

    static assert(isInstanceOf!(MyTemplate, MyT1));
    static assert(isInstanceOf!(MyTemplate, MyT2));

    // 関係ない型については false を返します
    static assert(!isInstanceOf!(MyTemplate, int));
    static assert(!isInstanceOf!(MyTemplate, string));
}

/++
関数が右辺値/左辺値で呼ぶことができるか確認する方法
+/
unittest
{
    import std.traits: rvalueOf, lvalueOf;
    void foo(int a) {}
    void bar(ref int a) {}

    // fooは右辺値でも左辺値でも呼べるが
    // barは右辺値では呼ぶことができない。
    // このような引数の特徴を持つ関数を弁別する際に使う。
    static assert( __traits(compiles, foo(rvalueOf!int)));
    static assert( __traits(compiles, foo(lvalueOf!int)));
    static assert(!__traits(compiles, bar(rvalueOf!int)));
    static assert( __traits(compiles, bar(lvalueOf!int)));
}

/++
要素の型を得る

ElementTypeがそれっぽく見えるが、実はForeachTypeのほうが扱いやすい。
See_Also:
    - https://dlang.org/phobos/std_range_primitives.html#ElementType
    - https://dlang.org/phobos/std_traits.html#ForeachType
+/
unittest
{
    import std.range: ElementType;
    import std.traits: ForeachType;

    // 適当にレンジを作成
    struct Range
    {
        uint[] ary;
        uint front() const { return ary[0]; }
        void popFront() { ary = ary[1..$]; }
        bool empty() const { return ary.length == 0; }
    }

    // Rangeは同じように扱ってくれる
    static assert(is(ElementType!Range == uint));
    static assert(is(ForeachType!Range == uint));

    // 配列でも同じように扱ってくれる
    static assert(is(ElementType!(uint[]) == uint));
    static assert(is(ForeachType!(uint[]) == uint));

    // ElementTypeの場合はcharからdcharへの変換が行われてしまうが
    // ForeachTypeの場合はcharのまま取り扱ってくれる
    static assert(is(ElementType!(char[]) == dchar));
    static assert(is(ForeachType!(char[]) == char));

    // Foreach over Delegates
    // https://dlang.org/spec/statement.html#foreach_over_delegates
    // デリゲートではElementTypeはうまく扱ってくれない(void判定されてしまう)
    alias DgRange = int delegate(scope int delegate(ref uint) dg);
    static assert(!is(ElementType!DgRange == uint));
    static assert( is(ForeachType!DgRange == uint));

    // opApplyでforeachできる構造体を作成
    struct Iterable
    {
        uint[] ary;
        int opApply(scope int delegate(ref uint a) dg)
        {
            int result = 0;
            foreach (item; ary)
            {
                result = dg(item);
                if (result)
                    break;
            }
            return result;
        }
    }
    // ElementTypeではopApplyのある構造体は扱えない
    // また、ForeachTypeでも複数opApplyがオーバーロードされている場合は
    // コンパイルエラーが発生します。
    static assert(!is(ElementType!Iterable == uint));
    static assert( is(ForeachType!Iterable == uint));
}
