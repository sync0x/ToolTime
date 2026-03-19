#include "harness.h"

static const char *kBuiltinFont = "BitstreamVeraSans-Roman-builtin.ttf";

TEST_CASE(builtin_font_invariants) {
    CHECK_LOAD("normal.slvs");

    Request *r = SK.GetRequest(hRequest { 4 });
    CHECK_TRUE(r != NULL);
    CHECK_TRUE(r->type == Request::Type::TTF_TEXT);
    CHECK_EQ_STR(r->font, kBuiltinFont);
    CHECK_TRUE(r->aspectRatio > 0.0);

    Entity *e = SK.GetEntity(hRequest { 4 }.entity(0));
    CHECK_TRUE(e != NULL);
    CHECK_TRUE(e->type == Entity::Type::TTF_TEXT);
    CHECK_EQ_STR(e->font, kBuiltinFont);
    CHECK_TRUE(e->aspectRatio > 0.0);

    TtfFont *tf = SS.fonts.LoadFont(r->font);
    CHECK_TRUE(tf != NULL);
    CHECK_TRUE(tf->IsResource());
    CHECK_EQ_STR(tf->FontFileBaseName(), kBuiltinFont);
}

TEST_CASE(builtin_render_xy) {
    CHECK_LOAD("normal.slvs");
    CHECK_RENDER("normal.png");
}

TEST_CASE(builtin_render_iso) {
    CHECK_LOAD("normal.slvs");
    CHECK_RENDER_ISO("normal_iso.png");
}
