# Fantasdic
# Copyright (C) 2006 - 2007 Mathieu Blondel
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

module Fantasdic
module UI

    class PreferencesDialog < GladeBase
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        SEL = 1
        UNSEL = 0

        SELECTION = 0
        NAME = 1


        def initialize(parent, statusicon, &callback_proc)
            super("preferences_dialog.glade")
            @main_app = parent
            @preferences_dialog.transient_for = parent
            @preferences_dialog.modal = true
            @statusicon = statusicon
            @prefs = Preferences.instance

            @callback_proc = callback_proc
            initialize_ui
            initialize_signals
        end

        private

        def initialize_signals
            initialize_dictionaries_signals
            initialize_startup_signals
            initialize_proxy_signals
        end

        def initialize_proxy_signals
            @enable_proxy_checkbutton.signal_connect("toggled") do
                @proxy_settings_table.sensitive = \
                    @enable_proxy_checkbutton.active?
            end

            @enable_http_proxy_checkbutton.signal_connect("toggled") do
                @http_proxy_settings_table.sensitive = \
                    @enable_http_proxy_checkbutton.active?
            end

            @proxy_combobox.signal_connect("changed") do
                if @proxy_combobox.active == 0 # SOCKS
                    @socks_proxy_vbox.visible = true
                    @http_proxy_vbox.visible = false
                elsif @proxy_combobox.active == 1 # HTTP
                    @socks_proxy_vbox.visible = false
                    @http_proxy_vbox.visible = true
                end
            end
        end

        def initialize_startup_signals
            @lookup_at_start_checkbutton.signal_connect("toggled") do
                @prefs.lookup_at_start = @lookup_at_start_checkbutton.active?
            end

            @show_in_tray_checkbutton.signal_connect("toggled") do
                @dont_quit_checkbutton.sensitive = \
                    @dont_show_at_startup_checkbutton.sensitive = \
                        @show_in_tray_checkbutton.active?


                if !@show_in_tray_checkbutton.active?
                    @dont_quit_checkbutton.active = false
                    @dont_show_at_startup_checkbutton.active = false
                end

                @prefs.show_in_tray = @show_in_tray_checkbutton.active?

                if @statusicon
                    @statusicon.visible = @show_in_tray_checkbutton.active?
                end
            end

            @dont_quit_checkbutton.signal_connect("toggled") do
                @prefs.dont_quit = @dont_quit_checkbutton.active?
            end

            @dont_show_at_startup_checkbutton.signal_connect("toggled") do
                @prefs.dont_show_at_startup = \
                    @dont_show_at_startup_checkbutton.active?
            end
        end

        def initialize_dictionaries_signals
            @show_help_button.signal_connect("clicked") do
                Browser::open_help("fantasdic-preferences")
            end

            @preferences_close_button.signal_connect("clicked") do
                @prefs.enable_proxy = @enable_proxy_checkbutton.active?
                @prefs.proxy_host = @proxy_host_entry.text
                @prefs.proxy_port = @proxy_port_entry.text
                @prefs.proxy_username = @proxy_username_entry.text
                @prefs.proxy_password = @proxy_password_entry.text

                @prefs.enable_http_proxy = \
                    @enable_http_proxy_checkbutton.active?
                @prefs.http_proxy_host = @http_proxy_host_entry.text
                @prefs.http_proxy_port = @http_proxy_port_entry.text


                @callback_proc.call
                @preferences_dialog.hide
            end

            @add_dictionary_button.signal_connect("clicked") do
                AddDictionaryDialog.new(@preferences_dialog) do |name, hash|
                    hash[:selected] = SEL
                    @prefs.add_dictionary(name, hash)
                    append_dictionary(SEL, name)
                end
            end

            @remove_dictionary_button.signal_connect("clicked") do
                selection = @dictionary_treeview.selection.selected
                name = selection[NAME]
                @list_store.remove(selection)
                @prefs.delete_dictionary(name)
            end

            @configure_dictionary_button.signal_connect("clicked") do
                selected_iter = @dictionary_treeview.selected_iter
                dicname = selected_iter[NAME]
                hash = @prefs.dictionaries_infos[dicname]
                AddDictionaryDialog.new(@preferences_dialog, dicname, hash) do
                    |new_name, new_hash|
                    if new_name != dicname
                        @prefs.dictionary_replace_name(dicname, new_name)
                        selected_iter[NAME] = new_name
                    end
                    new_hash[:selected] = selected_iter[SELECTION]
                    @prefs.update_dictionary(new_name, new_hash)
                end
            end

            @dictionary_up_button.signal_connect("clicked") do
                iter = @dictionary_treeview.selection.selected
                name = iter[NAME]
                old_path = iter.path
                new_path = iter.path
                new_path.prev!
                model = @dictionary_treeview.model
                model.move_after(model.get_iter(new_path), iter)
                sensitize_buttons
                # up graphically = down in the array
                @prefs.dictionary_down(name)
            end

            @dictionary_down_button.signal_connect("clicked") do
                iter = @dictionary_treeview.selection.selected
                name = iter[NAME]
                next_iter = iter.dup
                old_path = next_iter.path
                next_iter.next!
                new_path = next_iter.path
                @dictionary_treeview.model.move_after(iter, next_iter)
                sensitize_buttons
                # down graphically = up in the array
                @prefs.dictionary_up(name)
            end
        end

        def initialize_ui
            @dictionaries_nb_image.pixbuf = Icon::LOGO_22X22

            @tray_vbox.visible = !@statusicon.nil?
            @dont_quit_checkbutton.active = @prefs.dont_quit
            @dont_show_at_startup_checkbutton.active = \
                @prefs.dont_show_at_startup
            @show_in_tray_checkbutton.active = @prefs.show_in_tray

            @lookup_at_start_checkbutton.active = @prefs.lookup_at_start

            @enable_proxy_checkbutton.active = @prefs.enable_proxy
            @proxy_settings_table.sensitive = @prefs.enable_proxy

            @enable_http_proxy_checkbutton.active = @prefs.enable_http_proxy
            @http_proxy_settings_table.sensitive = @prefs.enable_http_proxy

            @http_proxy_vbox.visible = false

            @proxy_combobox.model = Gtk::ListStore.new(String)
            [_("SOCKS 5 proxy"), _("HTTP proxy")].each do |str|
                row = @proxy_combobox.model.append
                row[0] = str
            end
            @proxy_combobox.active = 0

            [[@proxy_host_entry, @prefs.proxy_host],
             [@proxy_port_entry, @prefs.proxy_port],
             [@proxy_username_entry, @prefs.proxy_username],
             [@proxy_password_entry, @prefs.proxy_password],
             [@http_proxy_host_entry, @prefs.http_proxy_host],
             [@http_proxy_port_entry, @prefs.http_proxy_port]
            ].each do |entry,pref|
                entry.text = pref if pref and !pref.strip.empty?
            end

            @list_store = Gtk::ListStore.new(Fixnum,String)

            @dictionary_treeview.model = @list_store
            @dictionary_treeview.selection.mode = Gtk::SELECTION_SINGLE

            renderer = Gtk::CellRendererToggle.new
            col = Gtk::TreeViewColumn.new("Active", renderer, :active => 0)
            @dictionary_treeview.append_column(col)

            renderer.signal_connect("toggled") do |toggled,row_iter|
                iter = @list_store.get_iter(row_iter)
                selected = iter[SELECTION]
                dicname = iter[NAME]
                if(selected == SEL)
                    iter[SELECTION] = UNSEL
                    @prefs.dictionaries_infos[dicname][:selected] = UNSEL
                else
                    iter[SELECTION] = SEL
                    @prefs.dictionaries_infos[dicname][:selected] = SEL
                end
            end

            renderer = Gtk::CellRendererText.new
            renderer.editable = false # to true if lines below commented out
            col = Gtk::TreeViewColumn.new("Dictionary", renderer, :text => 1)
            @dictionary_treeview.append_column(col)

            # renderer.signal_connect("edited") do |entry,row_iter,new|
            #     old = @list_store.get_iter(row_iter)[NAME]
            #     @list_store.get_iter(row_iter)[NAME] = new
            #     @prefs.dictionary_replace_name(old, new)
            # end

            sensitize_buttons

            @dictionary_treeview.selection.signal_connect("changed") do
                sensitize_buttons
            end

            update_dic_list
        end

        def sensitize_buttons
            selected_iter = @dictionary_treeview.selected_iter
            if selected_iter.nil?
                @dictionary_up_button.sensitive = false
                @dictionary_down_button.sensitive = false
                @remove_dictionary_button.sensitive = false
                @configure_dictionary_button.sensitive = false
            else
                @remove_dictionary_button.sensitive = \
                    @configure_dictionary_button.sensitive = \
                    @dictionary_treeview.has_row_selected?
                iter_last = \
                    @list_store.get_iter((@list_store.nb_rows - 1).to_s)
                @dictionary_up_button.sensitive = \
                    ((selected_iter != @list_store.iter_first) and
                     (not selected_iter.nil?))
                @dictionary_down_button.sensitive = \
                    ((selected_iter != iter_last) and (not selected_iter.nil?))
            end
        end

        def update_dic_list
            @list_store.clear
            @prefs.dictionaries.each do |name|
                hash = @prefs.dictionaries_infos[name]
                append_dictionary(hash[:selected], name)
            end
        end

        def append_dictionary(sel, name)
            row = @list_store.append()
            row[SELECTION] = sel
            row[NAME] = name
        end

    end

end
end
