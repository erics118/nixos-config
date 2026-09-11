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
          # fit to page width so docs open at a readable size
          startup_commands = [
            "toggle_synctex"
            "fit_to_page_width"
          ];

          # option-click anywhere does inverse search (sioyek has no cmd/super
          # click; synctex_under_cursor works regardless of synctex mode)
          alt_click_command = "synctex_under_cursor";

          # disable middle-click / shift-middle-click text search (default to
          # Google Scholar / Libgen); a non a-z value fails sioyek's engine guard
          middle_click_search_engine = "-";
          shift_middle_click_search_engine = "-";

          # prevent scrolling past the first and last page
          scroll_past_document_ends = "0";

          # reuse the same window so forward search lands in one place
          should_launch_new_window = "0";
          should_launch_new_instance = "0";

          # nicer navigation while reading/editing
          wheel_zoom_on_cursor = "1";
          should_draw_unrendered_pages = "1";
          super_fast_search = "1";
          case_sensitive_search = "0";

          # dark band between pages so page boundaries are clear
          page_separator_width = "15";
          page_separator_color = "0.118 0.118 0.118";
          background_color = "0.118 0.118 0.118";

          # quality-of-life
          check_for_updates_on_startup = "0";
          smooth_scroll_speed = "3";
          smooth_scroll_drag = "3000";
        };

        # mac cmd equivalents alongside the default ctrl bindings
        bindings = {
          copy = [
            "<C-c>"
            "<D-c>"
          ];
          search = [
            "<C-f>"
            "/"
            "<D-f>"
          ];
          new_window = [
            "<C-t>"
            "<D-t>"
          ];
          close_window = [
            "<C-w>"
            "<D-w>"
          ];
          open_document = [
            "o"
            "<D-o>"
          ];
          quit = [
            "q"
            "<D-q>"
          ];

          # unbind external (browser) search of selected text
          external_search = [ "<unbound>" ];
        };
      };
    };
}
