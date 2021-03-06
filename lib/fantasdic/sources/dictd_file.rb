# Fantasdic
# Copyright (C) 2008 Mathieu Blondel
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

require "zlib"

module Fantasdic
module Source

class DictdIndex < DictionaryIndex

    B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".
          split(//)

    # Returns the decoded value or nil.
    def self.b64_decode(str)
        str = str.split(//)
        return 0 if str.length == 0

        retval = 0
        shiftval = 0

        (str.length - 1).downto(0) do |i|
            val = B64.index(str[i])
            unless val
                retval = nil
                break
            end
            retval = retval | (val << shiftval)
            shiftval += 6
        end
        retval
    end

    # Returns the offset of the previous word in the index or nil.
    def get_prev_offset(offset)
        return nil if offset <= 1

        offset -= 1

        if offset - BUFFER_SIZE < 0
            length = offset
            offset = 0
        else
            offset -= BUFFER_SIZE
            length = BUFFER_SIZE
        end

        self.seek(offset)
        buf = self.read(length)

        i = buf.rindex("\n")
        if i.nil?
            0
        else
            offset += i + 1
            offset
        end
    end

    # Returns whether the current offset is the beginning of an entry or not
    def is_entry?(offset)
        return true if offset == 0
        return false if offset < 0
        self.seek(offset - 1)
        char = self.read(1)
        char == "\n" ? true : false
    end

    # Returns the offset of the next word in the index or nil.
    def get_next_offset(offset)
        self.seek(offset)
        buf = self.read(BUFFER_SIZE)

        return nil if buf.nil?

        i = buf.index("\n")
        if i.nil?
            nil
        else
            offset += i + 1
            offset
        end
    end

    def self.get_word_end(buf)
        buf.index("\t") - 1
    end

    def self.get_fields(str)
        word, word_offset, word_len = str.chomp.split("\t")
        [word, DictdIndex.b64_decode(word_offset),
         DictdIndex.b64_decode(word_len)]
    end

    def match_binary_search(word, &comp)
        binary_search_all(word) do |s1, s2|
            comp.call(s1.downcase, s2.downcase)
        end
    end

    def match_suffix(word)
        word = Regexp.escape(word)
        self.grep(/#{word}\t/).map do |line|
            DictdIndex.get_fields(line)
        end.find_all do |curr_word, offset, len|
            curr_word =~ /#{word}$/
        end
    end

    def match_substring(word)
        word = Regexp.escape(word)
        self.grep(/#{word}/).map do |line|
            DictdIndex.get_fields(line)
        end.find_all do |curr_word, offset, len|
            curr_word.include?(word)
        end
    end

    def get_word_list
        self.rewind
        self.lines.map { |line| DictdIndex.get_fields(line) }
    end

end

class DictdFile < Base

    authors ["Mathieu Blondel"]
    title  _("Dictd file")
    description _("Look up words in files aimed for the dictd server.")
    license Fantasdic::GPL
    copyright "Copyright (C) 2008 Mathieu Blondel"
    no_databases true

    STRATEGIES_DESC = {
        "define" => "Results match with the word exactly.",
        "prefix" => "Results match with the beginning of the word.",
        "word" => "Results have one word that matches with the word.",
        "substring" => "Results have a portion that contains the word.",
        "suffix" => "Results match with the end of the word.",
        "stem" => "Results share the same root as the word.",
        "lev" => "Results are close to the word according to the " + \
                 "levenshtein distance.",
        "soundex" => "Results have similar pronunciation according " + \
                     "to the soundex algorithm.",
        "metaphone" => "Results have similar pronunciation according " + \
                       "to the metaphone algorithm.",
        "metaphone2" => "Results have similar pronunciation according " + \
                       "to the double metaphone algorithm.",
        "regexp" => "Results match the regular expression."
    }

    class ConfigWidget < FileSource::ConfigWidget

        def initialize(*args)
            super(*args)

            @choose_file_message = _("Select a dictd file")
            @file_extensions = [["*.index", _("Index files")]]
            @encodings = []

            initialize_ui
            initialize_data
            initialize_signals
        end

    end

    def check_validity
        n_errors = 0
        n_lines = 0

        dictd_file_open do |index_file, dict_file|
            index_file.each_line do |line|
                line.chomp!
                word, offset, len = line.split("\t")
                if offset.nil? or len.nil?
                    n_errors += 1
                elsif not DictdIndex.b64_decode(offset) or \
                      not DictdIndex.b64_decode(offset)

                    n_errors += 1
                end

                n_lines += 1

                break if n_lines >= 1000
            end
        end

        if (n_errors.to_f / n_lines) >= 0.2
            raise Source::SourceError,
                    _("This file is not a valid index file!")
        end
    end

    def available_strategies
        STRATEGIES_DESC
    end

    def define(db, word)
        db = File.basename(@config[:filename]).slice(0...-6)
        db_capitalize = db.capitalize

        dictd_file_open do |index_file, dict_file|
            index_file.match_exact(word).map do |match, offset, len|
                defi = Definition.new
                defi.word = match

                body = get_definition(dict_file, offset, len)
                if body
                    defi.body = body.strip
                else
                    msg = "Match exists in index file %s "
                    msg += "(offset: %d, len: %d) "
                    msg += "but could not be reach in dictionary %s."
                    msg = msg % [index_file.path, offset, len, dict_file.path]
                    defi.body = msg
                end

                defi.database = db
                defi.description = db_capitalize
                defi
            end
        end
    end

    def match(db, strat, word)
        matches = dictd_file_open do |index_file, dict_file|
            meth = "match_#{strat}"
            if index_file.respond_to? meth
                index_file.send(meth, word)
            else
                []
            end.map do |match, offset, len|
                match
            end
        end

        hsh = {}
        db = File.basename(@config[:filename])
        hsh[db] = matches unless matches.empty?
        hsh
    end

    private

    def get_definition(file, offset, len)
        file.pos = offset
        file.read(len)
    end

    def dictd_file_open
        if !File.readable? @config[:filename]
            raise Source::SourceError,
                    _("Cannot open file %s.") % @config[:filename]
        end

        dict_file = @config[:filename].gsub(/.index$/, ".dict")
        dict_gz_file = dict_file + ".dz"

        if !File.readable? dict_file and !File.readable? dict_gz_file
            raise Source::SourceError,
            _("Couldn't find .dict or .dict.dz dictionary file.")
        elsif File.readable? dict_file
            dict_file = File.new(dict_file)
        else
            begin
                dict_file = Dictzip.new(dict_gz_file)
            rescue DictzipError => e
                raise Source::SourceError, e.to_s
            end
        end

        index_file = DictdIndex.new(@config[:filename])

        if block_given?
            ret = yield(index_file, dict_file)

            index_file.close
            dict_file.close

            ret
        else
            [@config[:filename], dict_file]
        end
    end

end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::DictdFile)
