#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess

REPO_BASE = '/var/www/vps-infra/volumes/infra/registry/docker/registry/v2/repositories'
KEEP_STATIC = {'dev', 'qa', 'uat', 'prod', 'latest', 'main', 'master', 'staging'}
KEEP_RECENT_COUNT = 3

def prune_repository_tags(tags_dir):
    if not os.path.isdir(tags_dir):
        return 0
    
    all_tags = os.listdir(tags_dir)
    dynamic_tags = [t for t in all_tags if t not in KEEP_STATIC]
    # Sort by modification time, newest first
    dynamic_tags.sort(key=lambda t: os.path.getmtime(os.path.join(tags_dir, t)), reverse=True)
    
    deleted_count = 0
    to_delete = dynamic_tags[KEEP_RECENT_COUNT:]
    for tag in to_delete:
        tag_path = os.path.join(tags_dir, tag)
        try:
            shutil.rmtree(tag_path)
            deleted_count += 1
        except Exception as e:
            print(f"Error removing {tag_path}: {e}", file=sys.stderr)
            
    return deleted_count

def main():
    if not os.path.exists(REPO_BASE):
        print(f"Registry repositories directory not found: {REPO_BASE}")
        return

    total_deleted = 0
    for entry in sorted(os.listdir(REPO_BASE)):
        path = os.path.join(REPO_BASE, entry)
        tags_dir = os.path.join(path, '_manifests', 'tags')
        if os.path.isdir(tags_dir):
            cnt = prune_repository_tags(tags_dir)
            total_deleted += cnt
            if cnt > 0:
                print(f"Pruned {cnt} old tags from {entry}")
        elif os.path.isdir(path):
            # Nested repository (e.g. tmk/ci-web)
            for sub in os.listdir(path):
                sub_tags = os.path.join(path, sub, '_manifests', 'tags')
                if os.path.isdir(sub_tags):
                    cnt = prune_repository_tags(sub_tags)
                    total_deleted += cnt
                    if cnt > 0:
                        print(f"Pruned {cnt} old tags from {entry}/{sub}")

    print(f"\nTotal pruned tags: {total_deleted}")

if __name__ == '__main__':
    main()
