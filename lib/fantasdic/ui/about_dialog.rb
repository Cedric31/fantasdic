# Fantasdic
# Copyright (C) 2006 Mathieu Blondel
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

module Fantasdic
module UI
    class AboutDialog
        GPL = <<EOL
Fantasdic is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

Fantasdic is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public
License along with Fantasdic; see the file COPYING.  If not,
write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.
EOL

        Gtk::AboutDialog.set_url_hook do |about, url|
            prefs = Preferences.instance
            browser = prefs.get_browser
            if browser
                prefs.open_url(browser, url)
            else
                ErrorDialog.new(about, _("Could not open browser."))
            end
        end

        def self.show(parent)
            Gtk::AboutDialog.show(parent,
            "name" => Fantasdic::TITLE,
            "version" => Fantasdic::VERSION,
            "copyright" => Fantasdic::COPYRIGHT,
            "comments" => Fantasdic::DESCRIPTION,
            "authors" => Fantasdic::AUTHORS,
            #"documenters" => Fantasdic::DOCUMENTERS,
            "translator_credits" => Fantasdic::TRANSLATORS.join("\n"),
            "website" => Fantasdic::WEBSITE_URL,
            #"logo" => Icon::LOGO,
            "license" => GPL)
        end

    end
    
end
end
