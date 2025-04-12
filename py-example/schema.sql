create table if not exists users (
	id uuid primary key default gen_random_uuid(),
	email text not null,
	username text not null,
	password text not null,
	created_at timestamptz not null default now()
);

create table if not exists posts (
	id uuid primary key default gen_random_uuid(),
	text text not null,
	image_path text,
	user_id uuid not null references users(id) on update cascade on delete cascade,
	created_at timestamptz not null default now()
);

create table if not exists comments (
	id uuid primary key default gen_random_uuid(),
	text text not null,
	post_id uuid not null references posts(id) on update cascade on delete cascade,
	user_id uuid not null references users(id) on update cascade on delete cascade,
	created_at timestamptz not null default now()
);

create table if not exists post_likes (
	post_id uuid not null references posts(id) on update cascade on delete cascade,
	user_id uuid not null references users(id) on update cascade on delete cascade,
	primary key (post_id, user_id)
);

create table if not exists comment_likes (
	comment_id uuid not null references comments(id) on update cascade on delete cascade,
	user_id uuid not null references users(id) on update cascade on delete cascade,
	primary key (comment_id, user_id)
);
