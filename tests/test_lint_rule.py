#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

from oslotest import base

from lint_rules import ardana_action_name_should_match_rule
from lint_rules import ardana_arrays_multiline_rule
from lint_rules import ardana_exclude_vim_directives_rule
from lint_rules import ardana_forbidden_commands_rule
from lint_rules import ardana_hyphen_followed_by_space_rule
from lint_rules import ardana_hyphen_on_same_line_rule
from lint_rules import ardana_indents_x_two_spaces_rule
from lint_rules import ardana_line_length_rule
from lint_rules import ardana_lowercase_variables_rule
from lint_rules import ardana_mode_octal_or_symbolic_rule
from lint_rules import ardana_no_spaces_inside_square_brackets
from lint_rules import ardana_noqa
from lint_rules import ardana_reg_vars_end_in_result_rule
from lint_rules import ardana_spaces_around_variables_rule
from lint_rules import ardana_sudo_in_shell_command_rule
from lint_rules import ardana_sudo_in_top_level_rule
from lint_rules import ardana_sudo_is_deprecated_rule
from lint_rules import ardana_unnamed_task_rule
from lint_rules import ardana_use_key_value_syntax_rule

import sys

# When ansible-lint loads ardana_noqa, it does so outside any namespace,
# so fake this. We have to get the ardana_noqa module from sys.modules in each
# rule because ansible-lint doesn't allow us to do a regular import.
sys.modules['ardana_noqa'] = sys.modules['lint_rules.ardana_noqa']

VALID_FILE = {'path': 'file'}


class NoQATest(base.BaseTestCase):
    def setUp(self):
        super(NoQATest, self).setUp()
        ardana_noqa._NOQA.clear()

    def tearDown(self):
        super(NoQATest, self).tearDown()
        ardana_noqa._NOQA.clear()

    def _test(self, expect, *test):
        actual = [ardana_noqa.skip_match(VALID_FILE, line) for line in test][-1]
        self.assertEqual(expect, actual)

    def test_none(self):
        self._test(False, None)

    def test_empty(self):
        self._test(False, '')

    def test_noqa(self):
        self._test(True, 'xx  # noqa')

    def test_noqa_on(self):
        self._test(True, ' # noqa-on')

    def test_noqa_off(self):
        self._test(True, ' # noqa-off')

    def test_noqa_stays_on(self):
        self._test(True, '# noqa-on',
                         'xx')

    def test_noqa_turns_off(self):
        self._test(False, '# noqa-on',
                          '# noqa-off',
                          'xx',)

    def test_noqa_turns_off_across_files(self):
        ardana_noqa.skip_match({'path': 'aaa'}, '# noqa-on')
        actual = ardana_noqa.skip_match({'path': 'bbb'}, 'xx')
        self.assertEqual(False, actual)


class BaseTest(base.BaseTestCase):

    def assertInvalidLine(self, file, line):
        self.assertTrue(self.lint_rule.match(file, line))

    def assertValidLine(self, file, line):
        self.assertFalse(self.lint_rule.match(file, line))

    def assertInvalidTask(self, file, task):
        self.assertTrue(self.lint_rule.matchtask(file, task))

    def assertValidTask(self, file, task):
        self.assertFalse(self.lint_rule.matchtask(file, task))


class ActionNameShouldMatchLintTest(BaseTest):

    def setUp(self):
        super(ActionNameShouldMatchLintTest, self).setUp()
        self.lint_rule =\
            ardana_action_name_should_match_rule.ArdanaActionNameShouldMatchRule()

    def test_simple(self):
        valid_task = {'name': 'role_name | valid_task | description'}
        valid_file = {'path': 'roles/role_name/tasks/valid_task.yml'}
        invalid_role_name = {'name': 'invalid | valid_task | description'}
        invalid_task_name = {'name': 'role_name | invalid_task | description'}

        self.assertValidTask(valid_file, valid_task)
        self.assertInvalidTask(valid_file, invalid_role_name)
        self.assertInvalidTask(valid_file, invalid_task_name)


class ArraysMultilineLintTest(BaseTest):

    def setUp(self):
        super(ArraysMultilineLintTest, self).setUp()
        self.lint_rule =\
            ardana_arrays_multiline_rule.ArdanaArraysMultilineRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "    my_array: -foo -bar -buzz")
        self.assertInvalidLine(VALID_FILE, " - foo - bar - buzz")
        self.assertValidLine(VALID_FILE, "    - foo")
        self.assertValidLine(VALID_FILE, "- hosts: NOV-CMP")


class ExcludeVimDirectivesLintTest(BaseTest):

    def setUp(self):
        super(ExcludeVimDirectivesLintTest, self).setUp()
        self.lint_rule =\
            ardana_exclude_vim_directives_rule.ArdanaExcludeVimDirectivesRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "# vim:")


class ForbiddenCommandsLintTest(BaseTest):

    def setUp(self):
        super(ForbiddenCommandsLintTest, self).setUp()
        self.lint_rule =\
            ardana_forbidden_commands_rule.ArdanaForbiddenCommandsRule()

    def test_simple(self):
        invalid_task1 = {'action': {'module': 'pip'}}
        valid_task = {'action': {'module': 'shell',
                                 'module_arguments': ['mkdir' '-p']}}
        self.assertInvalidTask(VALID_FILE, invalid_task1)
        self.assertValidTask(VALID_FILE, valid_task)


class HyphenFollowedBySpaceLintTest(BaseTest):

    def setUp(self):
        super(HyphenFollowedBySpaceLintTest, self).setUp()
        self.lint_rule =\
            ardana_hyphen_followed_by_space_rule.ArdanaHyphenFollowedBySpaceRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "    -foo")
        self.assertValidLine(VALID_FILE, "    - foo")


class HyphenOnSameLineLintTest(BaseTest):

    def setUp(self):
        super(HyphenOnSameLineLintTest, self).setUp()
        self.lint_rule =\
            ardana_hyphen_on_same_line_rule.ArdanaHyphenOnSameLineRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "    -")
        self.assertInvalidLine(VALID_FILE, " -")
        self.assertValidLine(VALID_FILE, "    - foo")


class IndentsXTwoSpacesLintTest(BaseTest):

    def setUp(self):
        super(IndentsXTwoSpacesLintTest, self).setUp()
        self.lint_rule =\
            ardana_indents_x_two_spaces_rule.ArdanaIndentsXTwoSpacesRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, " - one")
        self.assertInvalidLine(VALID_FILE, "   - three")
        self.assertValidLine(VALID_FILE, "  - two")
        self.assertValidLine(VALID_FILE, "    - four")


class LineLengthLintTest(BaseTest):

    def setUp(self):
        super(LineLengthLintTest, self).setUp()
        self.lint_rule = \
            ardana_line_length_rule.ArdanaLineLengthRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "x" * 81)
        self.assertValidLine(VALID_FILE, "x" * 80)
        self.assertValidLine(VALID_FILE, "x" * 79)


class LowercaseVariablesLintTest(BaseTest):

    def setUp(self):
        super(LowercaseVariablesLintTest, self).setUp()
        self.lint_rule =\
            ardana_lowercase_variables_rule.ArdanaLowercaseVariablesRule()

    def assertCPVar(self, file, line):
        self.assertEqual(self.lint_rule.match(file, line),
                         "CP vars must be aliased in defaults/main.yml")

    def test_simple(self):
        top = {'path': 'top_level.yml'}
        self.assertInvalidLine(top, "{{ UPPERCASE }}")
        self.assertInvalidLine(top, "{{ UPPERCASE }}")
        self.assertInvalidLine(top, "{{ iNvAlId.advertises.lowercase }}")
        self.assertInvalidLine(top, "{{ iNvAlId.consumes_AnyCase.lowercase }}")
        self.assertInvalidLine(top, "{{ AnyCase.consumes_AnyCase.INvaLID }}")
        self.assertInvalidLine(top, "{{ same.vars_AnyCase.INvaLID }}")
        self.assertValidLine(top, "{{ UPPER.advertises.lower.case }}")
        self.assertValidLine(top, "{{ SAMECASE.advertises.lower[0].case }}")
        self.assertValidLine(top, "{{ SAMECASE.consumes_UPPER.lowercase }}")
        self.assertValidLine(top, "{{ SAMECASE.consumes_lower.lowercase }}")
        self.assertValidLine(top, "{{ SAMECASE.vars.lowercase }}")
        self.assertValidLine(top, "{{ SAMECASE.vars.lowercase }}")
        self.assertValidLine(top, "{{ lowercase }}")

        lower = {'path': 'roles/role_name/tasks/role_level.yml'}
        self.assertInvalidLine(lower, "{{ UPPERCASE }}")
        self.assertInvalidLine(lower, "{{ UPPERCASE }}")
        self.assertInvalidLine(lower, "{{ AnyCase.advertises.INvaLID }}")
        self.assertInvalidLine(lower, "{{ AnyCase.consumes_AnyCase.INVALID }}")
        self.assertInvalidLine(lower, "{{ AnyCase.vars_AnyCase.INVALID }}")
        self.assertCPVar(lower, "{{ UPPER.advertises.lower.case }}")
        self.assertCPVar(lower, "{{ lower.consumes_UPPER.lowercase }}")
        self.assertCPVar(lower, "{{ UPPER.consumes_lower.lowercase }}")
        self.assertCPVar(lower, "{{ UPPER.consumes_UPPER.lowercase }}")
        self.assertCPVar(lower, "{{ verb_hosts.UPPER }}")
        self.assertValidLine(lower, "{{ lowercase }}")
        self.assertValidLine(lower, "{{ function('var', 'VAR') }}")
        self.assertValidLine(lower, "{{ function('var-var', 'var.VaR.VAr') }}")


class ModeOctalOrSymbolicLintTest(BaseTest):
    def setUp(self):
        super(ModeOctalOrSymbolicLintTest, self).setUp()
        self.lint_rule =\
            ardana_mode_octal_or_symbolic_rule.ArdanaModeOctalOrSymbolicRule()

    def test_simple(self):
        modules = ['file', 'copy', 'template']
        valid = [0o700, '0700', 'u=rw,g=r,o=r', '{{ x }}']
        invalid = [0, '0000', 700, '700',
                   'u+rw,g-wx,o-rwx', 'rwxr--r--', 448.0]

        def mkjson(mode):
            return {'action': {'module': module, 'mode': mode}}

        for module in modules:
            for mode in valid:
                self.assertValidTask(VALID_FILE, mkjson(mode))
            for mode in invalid:
                self.assertInvalidTask(VALID_FILE, mkjson(mode))
            self.assertInvalidTask(VALID_FILE, {'action': {'module': module}})
        self.assertValidTask(
            VALID_FILE, {'action': {'module': 'file', 'state': 'absent'}})
        self.assertValidTask(
            VALID_FILE, {'action': {'module': 'file', 'state': 'link'}})


class RegVarsEndInResultLintTest(BaseTest):

    def setUp(self):
        super(RegVarsEndInResultLintTest, self).setUp()
        self.lint_rule =\
            ardana_reg_vars_end_in_result_rule.ArdanaRegVarsEndInResultRule()

    def test_simple(self):
        invalid_task1 = {'register': 'my_regval'}
        invalid_task2 = {'register': ['foo', 'ardana_notify_foo']}
        invalid_task3 = {'register': ['foo_result', 'foo']}
        invalid_task4 = {'register': ['foo', 'bar']}
        valid_task1 = {'register': 'foo_result'}
        valid_task2 = {'register': 'ardana_notify_foo'}
        valid_task3 = {'register': ['foo_result', 'ardana_notify_foo']}
        self.assertInvalidTask(VALID_FILE, invalid_task1)
        self.assertInvalidTask(VALID_FILE, invalid_task2)
        self.assertInvalidTask(VALID_FILE, invalid_task3)
        self.assertInvalidTask(VALID_FILE, invalid_task4)
        self.assertValidTask(VALID_FILE, valid_task1)
        self.assertValidTask(VALID_FILE, valid_task2)
        self.assertValidTask(VALID_FILE, valid_task3)


class SpacesAroundVariableLintTest(BaseTest):

    def setUp(self):
        super(SpacesAroundVariableLintTest, self).setUp()
        self.lint_rule =\
            ardana_spaces_around_variables_rule.ArdanaSpacesAroundVariablesRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "{{XX }}")
        self.assertInvalidLine(VALID_FILE, "{{XX}}")
        self.assertInvalidLine(VALID_FILE, "{{ XX}}")
        self.assertValidLine(VALID_FILE, "{{ XX }}")


class SudoInShellCommandLintTest(BaseTest):

    def setUp(self):
        super(SudoInShellCommandLintTest, self).setUp()
        self.lint_rule =\
            ardana_sudo_in_shell_command_rule.ArdanaSudoInShellCommandRule()

    def test_simple(self):
        invalid_task1 = {'action': {'module': 'command',
                                    'module_arguments': ['sudo', 'mkdir']}}
        invalid_task2 = {'action': {'module': 'shell',
                                    'module_arguments': ['sudo', 'mkdir']}}
        valid_task = {'action': {'module': 'shell',
                                 'module_arguments': ['mkdir' '-p']}}
        self.assertInvalidTask(VALID_FILE, invalid_task1)
        self.assertInvalidTask(VALID_FILE, invalid_task2)
        self.assertValidTask(VALID_FILE, valid_task)


class SudoInTopLevelLintTest(BaseTest):

    def setUp(self):
        super(SudoInTopLevelLintTest, self).setUp()
        self.lint_rule =\
            ardana_sudo_in_top_level_rule.ArdanaSudoInTopLevelRule()

    def test_simple(self):
        top = {'path': 'top_level.yml'}
        self.assertInvalidLine(top, "become: yes")
        lower = {'path': 'roles/role_name/tasks/role_level.yml'}
        self.assertValidLine(lower, "become: yes")


class SudoIsDeprecatedLintTest(BaseTest):

    def setUp(self):
        super(SudoIsDeprecatedLintTest, self).setUp()
        self.lint_rule =\
            ardana_sudo_is_deprecated_rule.ArdanaSudoIsDeprecatedRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "sudo:")
        self.assertValidLine(VALID_FILE, " a line that does not contain ")


class UnnamedTaskLintTest(BaseTest):

    def setUp(self):
        super(UnnamedTaskLintTest, self).setUp()
        self.lint_rule =\
            ardana_unnamed_task_rule.ArdanaUnnamedTaskRule()

    def test_simple(self):
        valid_task = {'action': {'module': 'shell'},
                      'name': 'role | task | description'}
        invalid_task = {'action': {'module': 'shell'}}

        self.assertValidTask(VALID_FILE, valid_task)
        self.assertInvalidTask(VALID_FILE, invalid_task)


class UseKeyValueSyntaxLintTest(BaseTest):

    def setUp(self):
        super(UseKeyValueSyntaxLintTest, self).setUp()
        self.lint_rule =\
            ardana_use_key_value_syntax_rule.ArdanaUseKeyValueSyntaxRule()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "key=value")
        self.assertValidLine(VALID_FILE, "key: value")
        self.assertValidLine(VALID_FILE,
                             "install_package: name=nova state=present")
        self.assertValidLine(VALID_FILE, "mode == 'AAA' or mode == 'BBB'")


class NoSpacesInsideSquareBracketsLintTest(BaseTest):

    def setUp(self):
        super(NoSpacesInsideSquareBracketsLintTest, self).setUp()
        self.lint_rule =\
            ardana_no_spaces_inside_square_brackets.ArdanaNoSpacesInSquareBrackets()

    def test_simple(self):
        self.assertInvalidLine(VALID_FILE, "foo[ 'bar' ]")
        self.assertInvalidLine(VALID_FILE, "foo['bar' ]")
        self.assertInvalidLine(VALID_FILE, "foo[ 'bar']")
        self.assertValidLine(VALID_FILE, "foo['bar']")
