{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      programs.sioyek = {
        enable = true;
        config = {
          text_highlight_color = "0.7 0.84 1";
          should_load_tutorial_when_no_other_file = "0";
          use_legacy_keybinds = "0";
          show_doc_path = "1";

          # auto-enable synctex so right-click does inverse search
          startup_commands = [ "toggle_synctex" ];

          # prevent scrolling past the first and last page
          scroll_past_document_ends = "0";

          # reuse the same window so forward search lands in one place
          should_launch_new_window = "0";
          should_launch_new_instance = "0";

          # nicer navigation while reading/editing
          wheel_zoom_on_cursor = "1";
          should_draw_unrendered_pages = "1";
          prerender_page_count = "3";
          super_fast_search = "1";
          case_sensitive_search = "0";

          # quality-of-life
          check_for_updates_on_startup = "0";
          smooth_scroll_speed = "3";
          smooth_scroll_drag = "3000";
        };
      };
    };
}
