#!/bin/sh
#
# Copyright (c) 2019 Rohit Ashiwal
#

test_description='tests to ensure compatibility between am and interactive backends'

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

GIT_AUTHOR_DATE="1999-04-02T08:03:20+05:30"
export GIT_AUTHOR_DATE

# This is a special case in which both am and interactive backends
# provide the same output. It was done intentionally because
# both the backends fall short of optimal behaviour.
test_expect_success 'setup' '
	git checkout -b topic &&
	q_to_tab >file <<-\EOF &&
	line 1
	Qline 2
	line 3
	EOF
	git add file &&
	git commit -m "add file" &&
	cat >file <<-\EOF &&
	line 1
	new line 2
	line 3
	EOF
	git commit -am "update file" &&
	git tag side &&
	test_commit commit1 foo foo1 &&
	test_commit commit2 foo foo2 &&
	test_commit commit3 foo foo3 &&

	git checkout --orphan master &&
	git rm --cached foo &&
	rm foo &&
	sed -e "s/^|//" >file <<-\EOF &&
	|line 1
	|        line 2
	|line 3
	EOF
	git add file &&
	git commit -m "add file" &&
	git tag main
'

test_expect_success '--ignore-whitespace works with apply backend' '
	cat >expect <<-\EOF &&
	line 1
	new line 2
	line 3
	EOF
	test_must_fail git rebase --apply main side &&
	git rebase --abort &&
	git rebase --apply --ignore-whitespace main side &&
	test_cmp expect file
'

test_expect_success '--ignore-whitespace works with merge backend' '
	cat >expect <<-\EOF &&
	line 1
	new line 2
	line 3
	EOF
	test_must_fail git rebase --merge main side &&
	git rebase --abort &&
	git rebase --merge --ignore-whitespace main side &&
	test_cmp expect file
'

test_expect_success '--ignore-whitespace is remembered when continuing' '
	cat >expect <<-\EOF &&
	line 1
	new line 2
	line 3
	EOF
	(
		set_fake_editor &&
		FAKE_LINES="break 1" git rebase -i --ignore-whitespace main side
	) &&
	git rebase --continue &&
	test_cmp expect file
'

test_expect_success '--committer-date-is-author-date works with apply backend' '
	GIT_AUTHOR_DATE="@1234 +0300" git commit --amend --reset-author &&
	git rebase --apply --committer-date-is-author-date HEAD^ &&
	git log -1 --pretty="format:%ai" >authortime &&
	git log -1 --pretty="format:%ci" >committertime &&
	test_cmp authortime committertime
'

test_expect_success '--committer-date-is-author-date works with merge backend' '
	GIT_AUTHOR_DATE="@1234 +0300" git commit --amend --reset-author &&
	git rebase -m --committer-date-is-author-date HEAD^ &&
	git log -1 --pretty="format:%ai" >authortime &&
	git log -1 --pretty="format:%ci" >committertime &&
	test_cmp authortime committertime
'

test_expect_success '--committer-date-is-author-date works with rebase -r' '
	git checkout side &&
	GIT_AUTHOR_DATE="@1234 +0300" git merge --no-ff commit3 &&
	git rebase -r --root --committer-date-is-author-date &&
	git log --pretty="format:%ai" >authortime &&
	git log --pretty="format:%ci" >committertime &&
	test_cmp authortime committertime
'

test_expect_success '--committer-date-is-author-date works when forking merge' '
	git checkout side &&
	GIT_AUTHOR_DATE="@1234 +0300" git merge --no-ff commit3 &&
	git rebase -r --root --strategy=resolve --committer-date-is-author-date &&
	git log --pretty="format:%ai" >authortime &&
	git log --pretty="format:%ci" >committertime &&
	test_cmp authortime committertime

'

test_expect_success '--committer-date-is-author-date works when committing conflict resolution' '
	git checkout commit2 &&
	GIT_AUTHOR_DATE="@1980 +0000" git commit --amend --only --reset-author &&
	git log -1 --format=%at HEAD >expect &&
	test_must_fail git rebase -m --committer-date-is-author-date \
		--onto HEAD^^ HEAD^ &&
	echo resolved > foo &&
	git add foo &&
	git rebase --continue &&
	git log -1 --format=%ct HEAD >actual &&
	test_cmp expect actual
'

# This must be the last test in this file
test_expect_success '$EDITOR and friends are unchanged' '
	test_editor_unchanged
'

test_done
