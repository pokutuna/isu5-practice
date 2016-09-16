package Isucon5::Web;

use strict;
use warnings;
use utf8;
use Kossy;
use DBIx::Handler;
use DBIx::Sunny;
use Encode;
use JSON::XS;
use Redis::Fast;

my $redis;
sub redis {
    $redis ||= Redis::Fast->new(
        read_timeout  => 1.0,
        write_timeout => 1.0,
        reconnect     => 1,
        encoding      => 'utf8',
    );
}

my $json_driver;
sub json_driver {
    $json_driver ||= JSON::XS->new->utf8->canonical;
}

my $db;
sub db {
    $db ||= do {
        my %db = (
            host => $ENV{ISUCON5_DB_HOST} || 'localhost',
            port => $ENV{ISUCON5_DB_PORT} || 3306,
            username => $ENV{ISUCON5_DB_USER} || 'root',
            password => $ENV{ISUCON5_DB_PASSWORD},
            database => $ENV{ISUCON5_DB_NAME} || 'isucon5q',
        );

        DBIx::Handler->new(
            "dbi:mysql:database=$db{database};host=$db{host};port=$db{port}", $db{username}, $db{password}, {
                RaiseError => 1,
                PrintError => 0,
                AutoInactiveDestroy => 1,
                mysql_enable_utf8   => 1,
                mysql_auto_reconnect => 1,
                RootClass => 'DBIx::Sunny',
            },
        );
    };
    $db->dbh;
}

my ($SELF, $C);
sub session {
    $C->stash->{session};
}

sub stash {
    $C->stash;
}

sub redirect {
    $C->redirect(@_);
}

sub abort_authentication_error {
    session()->{user_id} = undef;
    $C->halt(401, encode_utf8($C->tx->render('login.tx', { message => 'ログインに失敗しました' })));
}

sub abort_permission_denied {
    $C->halt(403, encode_utf8($C->tx->render('error.tx', { message => '友人のみしかアクセスできません' })));
}

sub abort_content_not_found {
    $C->halt(404, encode_utf8($C->tx->render('error.tx', { message => '要求されたコンテンツは存在しません' })));
}

sub authenticate {
    my ($email, $password) = @_;
    my $query = <<SQL;
SELECT u.id AS id, u.account_name AS account_name, u.nick_name AS nick_name, u.email AS email
FROM users u
JOIN salts s ON u.id = s.user_id
WHERE u.email = ? AND u.passhash = SHA2(CONCAT(?, s.salt), 512)
SQL
    my $result = db->select_row($query, $email, $password);
    if (!$result) {
        abort_authentication_error();
    }
    session()->{user_id} = $result->{id};
    return $result;
}

sub current_user {
    my ($self, $c) = @_;
    my $user = stash()->{user};

    return $user if ($user);

    return undef if (!session()->{user_id});

    $user = db->select_row(
        'SELECT id, account_name, nick_name, email FROM users WHERE id=?', session()->{user_id}
    );
    if (!$user) {
        session()->{user_id} = undef;
        abort_authentication_error();
    }
    return $user;
}

sub get_user {
    my ($user_id) = @_;
    my $user = redis->get("users:id:$user_id");
    abort_content_not_found() if (!$user);
    return json_driver->decode($user);
}

sub user_from_account {
    my ($account_name) = @_;
    my $user = redis->get("users:account_name:$account_name");
    abort_content_not_found() if (!$user);
    return json_driver->decode($user);
}

# MEMO a->b, b->a の関係で双方向で持ってるけどいみなさそう
sub is_friend {
    my ($another_id) = @_;
    my $user_id = session()->{user_id};
    # my $query = 'SELECT 1 AS cnt FROM relations WHERE (one = ? AND another = ?) OR (one = ? AND another = ?) LIMIT 1';
    # my $cnt = db->select_one($query, $user_id, $another_id, $another_id, $user_id);
    # return $cnt ? 1 : 0;
    return is_friend_redis($user_id, $another_id);
}

sub is_friend_account {
    my ($account_name) = @_;
    is_friend(user_from_account($account_name)->{id});
}

sub mark_footprint {
    my ($user_id) = @_;
    if ($user_id != current_user()->{id}) {
        my $query = <<SQL;
INSERT INTO footprints (user_id, owner_id) VALUES (?, ?)
ON DUPLICATE KEY UPDATE created_at = NOW()
SQL
        db->query($query, $user_id, current_user()->{id});
    }
}

# 自身かフレンドか
sub permitted {
    my ($another_id) = @_;
    $another_id == current_user()->{id} || is_friend($another_id);
}

my $PREFS;
sub prefectures {
    $PREFS ||= do {
        [
        '未入力',
        '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県', '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県', '新潟県', '富山県',
        '石川県', '福井県', '山梨県', '長野県', '岐阜県', '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県', '鳥取県', '島根県',
        '岡山県', '広島県', '山口県', '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'
        ]
    };
}

filter 'authenticated' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        if (!current_user()) {
            return redirect('/login');
        }
        $app->($self, $c);
    }
};

filter 'set_global' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        $SELF = $self;
        $C = $c;
        $C->stash->{session} = $c->req->env->{"psgix.session"};
        $app->($self, $c);
    }
};

get '/login' => sub {
    my ($self, $c) = @_;
    # TODO 定型文なのでテンプレートに書けそう
    $c->render('login.tx', { message => '高負荷に耐えられるSNSコミュニティサイトへようこそ!' });
};

post '/login' => [qw(set_global)] => sub {
    my ($self, $c) = @_;
    my $email = $c->req->param("email");
    my $password = $c->req->param("password");
    authenticate($email, $password);
    redirect('/');
};

get '/logout' => [qw(set_global)] => sub {
    my ($self, $c) = @_;
    session()->{user_id} = undef;
    redirect('/login');
};

get '/' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;

    my $profile = db->select_row(
        'SELECT * FROM profiles WHERE user_id = ?', current_user()->{id}
    );

    my $entries_query = <<SQL;
SELECT id, user_id, is_private, SUBSTRING_INDEX(body,\'\n\',1) AS title, created_at FROM entries WHERE user_id = ? ORDER BY created_at LIMIT 5
SQL
    my $entries = db->select_all($entries_query, current_user()->{id});

    # 自分のエントリへのコメント
    my $comments_for_me_query = <<SQL;
SELECT comments.*, users.account_name, users.nick_name
  FROM comments JOIN users ON comments.user_id = users.id
WHERE entry_author_id = ?
ORDER BY created_at DESC LIMIT 10
SQL
    my $comments_for_me = db->select_all($comments_for_me_query, current_user()->{id});

    # 事前に友だちだけを引いてくる
    my $curr_id = current_user()->{id};
    my $friend_ids = do {
        my $rows = db->select_all('SELECT another FROM relations WHERE one = ?', $curr_id);
        [ map { $_->{another} } @$rows ];
    };

    # フレンドの投稿新しいほうから10件
    my $entries_of_friends = db->select_all(
        'SELECT entries.id, SUBSTRING_INDEX(entries.body, \'\n\', 1) as title, entries.created_at FROM entries WHERE user_id IN (?) ORDER BY created_at DESC LIMIT 10', $friend_ids
    );
    for my $entry (@$entries_of_friends) {
        my $owner = get_user($entry->{user_id}); # TODO ユーザまとめて引く
        $entry->{account_name} = $owner->{account_name};
        $entry->{nick_name} = $owner->{nick_name};
    }

    # フレンドのコメントのうち新しいものから10件
    # コメント先エントリが private なら permitted のみ閲覧できる
    # XXX もうちょい JOIN しようとしたけど index 効かなくてスコア落ちてきた
    my $comments_query = <<SQL;
SELECT comments.* FROM comments
  JOIN entries ON comments.entry_id = entries.id
WHERE comments.user_id IN (?)
AND (entries.is_private = 0 OR entries.user_id in (?))
ORDER BY comments.created_at DESC LIMIT 10
SQL
    my $comments_of_friends = do {
        my $comments = db->select_all($comments_query, $friend_ids, [$curr_id, @$friend_ids]);

        # コメント先エントリを読み込む
        my $entries = db->select_all(
            'SELECT entries.*, users.nick_name, users.account_name FROM entries JOIN users ON entries.user_id = users.id WHERE entries.id IN (?)',
            [ map { $_->{entry_id} } @$comments ]
        );
        my $id_to_entry = +{ map { $_->{id} => $_ } @$entries };

        # 各コメントの著者名とエントリをセット
        for $c (@$comments) {
            my $owner = get_user($c->{user_id});
            $c->{account_name} = $owner->{account_name};
            $c->{nick_name} = $owner->{nick_name};
            $c->{entry} = $id_to_entry->{$c->{entry_id}};
        }

        $comments;
    };

    # フレンド数のみ取得
    my $friend_count = db->select_one(
        'SELECT COUNT(*) FROM relations WHERE one = ? OR another = ?',
        current_user()->{id}, current_user()->{id}
    ) // 0;

    # あしあと取得
    my $query = <<SQL;
SELECT
  footprints.user_id, footprints.owner_id, footprints.created_at as updated,
  users.account_name, users.nick_name
FROM footprints
  JOIN users ON footprints.user_id = users.id
WHERE footprints.user_id = ?
ORDER BY footprints.created_at DESC
LIMIT 10
SQL
    my $footprints = db->select_all($query, current_user()->{id});

    my $locals = {
        'user' => current_user(),
        'profile' => $profile,
        'entries' => $entries,
        'comments_for_me' => $comments_for_me,
        'entries_of_friends' => $entries_of_friends,
        'comments_of_friends' => $comments_of_friends,
        'friend_count' => $friend_count,
        'footprints' => $footprints
    };
    $c->render('index.tx', $locals);
};

get '/profile/:account_name' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $account_name = $c->args->{account_name};
    my $owner = user_from_account($account_name);
    my $prof = get_user($owner->{id});
    $prof = {} if (!$prof);
    my $is_permitted = permitted($owner->{id});
    my $query;
    if ($is_permitted) {
        $query = 'SELECT * FROM entries WHERE user_id = ? ORDER BY created_at LIMIT 5';
    } else {
        $query = 'SELECT * FROM entries WHERE user_id = ? AND is_private = 0 ORDER BY created_at LIMIT 5';
    }
    my $entries = [];
    for my $entry (@{db->select_all($query, $owner->{id})}) {
        my ($title, $content) = split(/\n/, $entry->{body}, 2);
        $entry->{title} = $title;
        $entry->{content} = $content; # template でさらに substr(0, 60) している
        push @$entries, $entry;
    }
    mark_footprint($owner->{id});
    my $locals = {
        owner => $owner,
        profile => $prof,
        entries => $entries,
        private => $is_permitted,
        is_friend => is_friend($owner->{id}),
        current_user => current_user(),
        prefectures => prefectures(),
    };
    $c->render('profile.tx', $locals);
};

post '/profile/:account_name' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $account_name = $c->args->{account_name};
    if ($account_name ne current_user()->{account_name}) {
        abort_permission_denied();
    }
    my $first_name =  $c->req->param('first_name');
    my $last_name = $c->req->param('last_name');
    my $sex = $c->req->param('sex');
    my $birthday = $c->req->param('birthday');
    my $pref = $c->req->param('pref');

    my $prof = db->select_row('SELECT * FROM profiles WHERE user_id = ?', current_user()->{id});
    if ($prof) {
      my $query = <<SQL;
UPDATE profiles
SET first_name=?, last_name=?, sex=?, birthday=?, pref=?, updated_at=CURRENT_TIMESTAMP()
WHERE user_id = ?
SQL
        db->query($query, $first_name, $last_name, $sex, $birthday, $pref, current_user()->{id});
    } else {
        my $query = <<SQL;
INSERT INTO profiles (user_id,first_name,last_name,sex,birthday,pref) VALUES (?,?,?,?,?,?)
SQL
        db->query($query, current_user()->{id}, $first_name, $last_name, $sex, $birthday, $pref);
    }
    redirect('/profile/'.$account_name);
};

get '/diary/entries/:account_name' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $account_name = $c->args->{account_name};
    my $owner = user_from_account($account_name);
    my $query;
    if (permitted($owner->{id})) {
        $query = 'SELECT * FROM entries WHERE user_id = ? ORDER BY created_at DESC LIMIT 20';
    } else {
        $query = 'SELECT * FROM entries WHERE user_id = ? AND is_private=0 ORDER BY created_at DESC LIMIT 20';
    }
    my $entries = [];
    for my $entry (@{db->select_all($query, $owner->{id})}) {
        my ($title, $content) = split(/\n/, $entry->{body}, 2);
        $entry->{title} = $title;
        $entry->{content} = $content;
        $entry->{comment_count} = db->select_one('SELECT COUNT(*) AS c FROM comments WHERE entry_id = ?', $entry->{id});
        push @$entries, $entry;
    }
    mark_footprint($owner->{id});
    my $locals = {
        owner => $owner,
        entries => $entries,
        myself => (current_user()->{id} == $owner->{id}),
    };
    $c->render('entries.tx', $locals);
};

get '/diary/entry/:entry_id' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;

    my $entry_id = $c->args->{entry_id};
    my $entry = db->select_row('SELECT * FROM entries WHERE id = ?', $entry_id);
    abort_content_not_found() if (!$entry);

    my $owner = get_user($entry->{user_id});
    if ($entry->{is_private} && !permitted($owner->{id})) {
        abort_permission_denied();
    }

    my ($title, $content) = split(/\n/, $entry->{body}, 2);
    $entry->{title} = $title;
    $entry->{content} = $content;

    my $comments = db->select_all(
        'SELECT comments.*, users.account_name, users.nick_name FROM comments JOIN users ON comments.user_id = users.id WHERE comments.entry_id = ?', $entry->{id}
    );

    mark_footprint($owner->{id});
    my $locals = {
        'owner' => $owner,
        'entry' => $entry,
        'comments' => $comments,
    };
    $c->render('entry.tx', $locals);
};

post '/diary/entry' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $query = 'INSERT INTO entries (user_id, is_private, body) VALUES (?,?,?)';
    my $title = $c->req->param('title');
    my $content = $c->req->param('content');
    my $is_private = $c->req->param('private') ? 1 : 0;
    my $body = ($title || "タイトルなし") . "\n" . $content;
    db->query($query, current_user()->{id}, $is_private, $body);
    redirect('/diary/entries/'.current_user()->{account_name});
};

post '/diary/comment/:entry_id' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $entry_id = $c->args->{entry_id};
    my $entry = db->select_row('SELECT * FROM entries WHERE id = ?', $entry_id);
    abort_content_not_found() if (!$entry);
    if ($entry->{is_private} && !permitted($entry->{user_id})) {
        abort_permission_denied();
    }
    my $query = 'INSERT INTO comments (entry_id, user_id, entry_author_id, comment) VALUES (?,?,?,?)';
    my $comment = $c->req->param('comment');
    db->query($query, $entry->{id}, current_user()->{id}, $entry->{user_id}, $comment);
    redirect('/diary/entry/'.$entry->{id});
};

get '/footprints' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $query = <<SQL;
SELECT
  footprints.user_id, footprints.owner_id, footprints.created_at as updated,
  users.account_name, users.nick_name
FROM footprints
  JOIN users ON footprints.owner_id = users.id
WHERE footprints.user_id = ?
ORDER BY footprints.created_at DESC
LIMIT 50
SQL
    my $footprints = db->select_all($query, current_user()->{id});
    $c->render('footprints.tx', { footprints => $footprints });
};

get '/friends' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $query = <<SQL;
SELECT relations.another, relations.created_at, users.account_name, users.nick_name
  FROM relations JOIN users ON relations.another = users.id
WHERE one = ?
ORDER BY created_at DESC
SQL
    my $friends = db->select_all($query, current_user()->{id});

    $c->render('friends.tx', { friends => $friends });
};

post '/friends/:account_name' => [qw(set_global authenticated)] => sub {
    my ($self, $c) = @_;
    my $account_name = $c->args->{account_name};
    if (!is_friend_account($account_name)) {
        my $user = user_from_account($account_name);
        abort_content_not_found() if (!$user);

        db->query(
            'INSERT INTO relations (one, another) VALUES (?,?), (?,?)',
            current_user()->{id}, $user->{id}, $user->{id}, current_user()->{id}
        );
        add_friend_redis(current_user()->{id}, $user->{id});

        redirect('/friends');
    }
};

sub add_friend_redis {
    my ($one_id, $another_id) = @_;
    my @sorted = sort { $a <=> $b } ($one_id, $another_id);
    my $key = sprintf 'is_friend:%s:%s', @sorted;
    redis->set($key, 1);
}

sub is_friend_redis {
    my ($one_id, $another_id) = @_;
    my @sorted = sort { $a <=> $b } ($one_id, $another_id);
    my $key = sprintf 'is_friend:%s:%s', @sorted;
    return redis->get($key) ? 1 : 0;
}

get '/initialize' => sub {
    my ($self, $c) = @_;
    # これはなんでやっている?
    # disk 埋まらないようにするため?
    # 追記型なので多すぎると遅くなっていくので単に削っているだけ?
    db->query("DELETE FROM relations WHERE id > 500000");
    db->query("DELETE FROM footprints WHERE id > 500000");
    db->query("DELETE FROM entries WHERE id > 500000");
    db->query("DELETE FROM comments WHERE id > 1500000");


    redis->flushdb;

    # userを全部redisに載せる
    my $users = db->select_all('SELECT * FROM users');
    for my $u (@$users) {
        my $data = json_driver->encode($u);
        my $id = $u->{id};
        my $name = $u->{account_name};
        redis->set("users:id:$id", $data, sub {});
        redis->set("users:account_name:$name", $data, sub {});
    }

    # friend を全部 redis に載せる
    my $relations = db->select_all('SELECT * FROM relations');
    add_friend_redis($_->{one}, $_->{another}) for @$relations;

    redis->wait_all_responses;

    1;
};

1;
