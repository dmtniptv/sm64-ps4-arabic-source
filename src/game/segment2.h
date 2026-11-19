#ifndef SEGMENT2_H
#define SEGMENT2_H

#include <PR/ultratypes.h>
#include <PR/gbi.h>

extern u8 seg2_course_name_table[];
extern u8 seg2_act_name_table[];
extern Gfx dl_rgba16_text_begin[];
extern Gfx dl_rgba16_text_end[];
extern Gfx dl_ia_text_begin[];
extern Gfx dl_ia_text_end[];
extern u8 texture_transition_star_half[];
extern u8 texture_transition_circle_half[];
extern u8 texture_transition_mario[];
extern u8 texture_transition_bowser_half[];
extern u8 texture_waterbox_water[];
extern u8 texture_waterbox_mist[];
extern u8 texture_waterbox_jrb_water[];
extern u8 texture_waterbox_unknown_water[];
extern u8 texture_waterbox_lava[];
extern Gfx dl_proj_mtx_fullscreen[];
extern Gfx dl_draw_quad_verts_0123[];
extern Gfx dl_screen_transition_end[];
extern Gfx dl_transition_draw_filled_region[];
extern Gfx dl_shadow_circle[];
extern Gfx dl_shadow_square[];
extern Gfx dl_shadow_9_verts[];
extern Gfx dl_shadow_4_verts[];
extern Gfx dl_shadow_end[];
extern Gfx dl_skybox_begin[];
extern Gfx dl_skybox_tile_tex_settings[];
extern Gfx dl_skybox_end[];
extern Gfx dl_waterbox_ia16_begin[];
extern Gfx dl_waterbox_rgba16_begin[];
extern Gfx dl_waterbox_end[];
extern Gfx dl_paintings_draw_ripples[];
extern Gfx dl_paintings_rippling_begin[];
extern Gfx dl_paintings_rippling_end[];
extern Gfx dl_paintings_env_mapped_begin[];
extern Gfx dl_paintings_env_mapped_end[];
extern u8 seg2_painting_triangle_mesh[];
extern u8 seg2_painting_mesh_neighbor_tris[];
extern u8* main_hud_lut[58];
extern Gfx dl_hud_img_load_tex_block[];
extern Gfx dl_hud_img_begin[];
extern Gfx dl_hud_img_end[];
extern void *main_font_lut[];
extern Gfx dl_ia_text_tex_settings[];
#ifdef ENABLE_ARABIC
extern const Gfx *const arabic_dialog_line_table[256][32];
extern const u8 arabic_dialog_line_count[256];
#include "text/ar/generated/ui_text_ids.h"
extern const Gfx *const arabic_ui_text_table[ARABIC_UI_TEXT_COUNT];
extern const u16 arabic_ui_text_width[ARABIC_UI_TEXT_COUNT];
extern const u8 arabic_ui_text_height[ARABIC_UI_TEXT_COUNT];
extern const Gfx *const arabic_credit_role_table[20][2];
extern const u16 arabic_credit_role_width[20][2];
extern const u8 arabic_credit_role_count[20];
extern const Gfx *const arabic_credit_name_table[20][3];
extern const u16 arabic_credit_name_width[20][3];
extern const u8 arabic_credit_name_count[20];
#endif
extern Gfx dl_rgba16_load_tex_block[];
extern void *main_credits_font_lut[];
extern u8* main_hud_camera_lut[6];
extern Gfx dl_draw_text_bg_box[];
extern Gfx dl_draw_triangle[];
extern void *seg2_dialog_table[];
extern Gfx dl_billboard_num_0[];
extern Gfx dl_billboard_num_1[];
extern Gfx dl_billboard_num_2[];
extern Gfx dl_billboard_num_3[];
extern Gfx dl_billboard_num_4[];
extern Gfx dl_billboard_num_5[];
extern Gfx dl_billboard_num_6[];
extern Gfx dl_billboard_num_7[];
extern Gfx dl_billboard_num_8[];
extern Gfx dl_billboard_num_9[];

#endif // SEGMENT2_H
