CREATE TABLE `ads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8_unicode_ci,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `target_url` text COLLATE utf8_unicode_ci,
  `organization_id` int(11) DEFAULT NULL,
  `live` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `bikeParams` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `params` text COLLATE utf8_unicode_ci,
  `bike_title` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `creator_id` int(11) DEFAULT NULL,
  `created_bike_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `bike_errors` text COLLATE utf8_unicode_ci,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `image_tmp` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `image_processed` tinyint(1) DEFAULT '1',
  `id_token` text COLLATE utf8_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `bikes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cycle_type_id` int(11) DEFAULT NULL,
  `serial_number` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `frame_model` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `manufacturer_id` int(11) DEFAULT NULL,
  `rear_tire_narrow` tinyint(1) DEFAULT '1',
  `frame_material_id` int(11) DEFAULT NULL,
  `number_of_seats` int(11) DEFAULT NULL,
  `propulsion_type_id` int(11) DEFAULT NULL,
  `creation_organization_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `stolen` tinyint(1) NOT NULL DEFAULT '0',
  `propulsion_type_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `manufacturer_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `zipcode` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cached_data` text COLLATE utf8_unicode_ci,
  `description` text COLLATE utf8_unicode_ci,
  `owner_email` text COLLATE utf8_unicode_ci,
  `thumb_path` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `video_embed` text COLLATE utf8_unicode_ci,
  `year` int(11) DEFAULT NULL,
  `has_no_serial` tinyint(1) NOT NULL DEFAULT '0',
  `creator_id` int(11) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `front_tire_narrow` tinyint(1) DEFAULT NULL,
  `primary_frame_color_id` int(11) DEFAULT NULL,
  `secondary_frame_color_id` int(11) DEFAULT NULL,
  `tertiary_frame_color_id` int(11) DEFAULT NULL,
  `handlebar_type_id` int(11) DEFAULT NULL,
  `handlebar_type_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `front_wheel_size_id` int(11) DEFAULT NULL,
  `rear_wheel_size_id` int(11) DEFAULT NULL,
  `rear_gear_type_id` int(11) DEFAULT NULL,
  `front_gear_type_id` int(11) DEFAULT NULL,
  `cached_attributes` text COLLATE utf8_unicode_ci,
  `additional_registration` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `belt_drive` tinyint(1) NOT NULL DEFAULT '0',
  `coaster_brake` tinyint(1) NOT NULL DEFAULT '0',
  `frame_size` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `frame_size_unit` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `serial_normalized` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `pdf` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cardId` int(11) DEFAULT NULL,
  `recovered` tinyint(1) NOT NULL DEFAULT '0',
  `paint_id` int(11) DEFAULT NULL,
  `registered_new` tinyint(1) DEFAULT NULL,
  `example` tinyint(1) NOT NULL DEFAULT '0',
  `creation_zipcode` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `creation_country_id` int(11) DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `stock_photo_url` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `current_stolenRecord_id` int(11) DEFAULT NULL,
  `listing_order` int(11) DEFAULT NULL,
  `approved_stolen` tinyint(1) DEFAULT NULL,
  `all_description` text COLLATE utf8_unicode_ci,
  `mnfg_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `frame_size_number` float DEFAULT NULL,
  `updator_id` int(11) DEFAULT NULL,
  `is_for_sale` tinyint(1) NOT NULL DEFAULT '0',
  `made_without_serial` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_bikes_on_organization_id` (`creation_organization_id`),
  KEY `index_bikes_on_primary_frame_color_id` (`primary_frame_color_id`),
  KEY `index_bikes_on_secondary_frame_color_id` (`secondary_frame_color_id`),
  KEY `index_bikes_on_tertiary_frame_color_id` (`tertiary_frame_color_id`),
  KEY `index_bikes_on_manufacturer_id` (`manufacturer_id`),
  KEY `index_bikes_on_current_stolenRecord_id` (`current_stolenRecord_id`),
  KEY `index_bikes_on_cycle_type_id` (`cycle_type_id`),
  KEY `index_bikes_on_cardId` (`cardId`),
  KEY `index_bikes_on_paint_id` (`paint_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `blogs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` text COLLATE utf8_unicode_ci,
  `title_slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8_unicode_ci,
  `body_abbr` text COLLATE utf8_unicode_ci,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `published_at` datetime DEFAULT NULL,
  `tags` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `published` tinyint(1) DEFAULT NULL,
  `old_title_slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `description_abbr` text COLLATE utf8_unicode_ci,
  `is_listicle` tinyint(1) NOT NULL DEFAULT '0',
  `index_image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `index_image_id` int(11) DEFAULT NULL,
  `index_image_lg` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `cgroups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `colors` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `priority` int(11) DEFAULT NULL,
  `display` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `components` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `description` text COLLATE utf8_unicode_ci,
  `manufacturer_id` int(11) DEFAULT NULL,
  `ctype_id` int(11) DEFAULT NULL,
  `ctype_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `bike_id` int(11) DEFAULT NULL,
  `front` tinyint(1) DEFAULT NULL,
  `rear` tinyint(1) DEFAULT NULL,
  `manufacturer_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `serial_number` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `is_stock` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_components_on_bike_id` (`bike_id`),
  KEY `index_components_on_manufacturer_id` (`manufacturer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `countries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `iso` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `ctypes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `secondary_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `has_multiple` tinyint(1) NOT NULL DEFAULT '0',
  `cgroup_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `customer_contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `user_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `creator_id` int(11) DEFAULT NULL,
  `creator_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `contact_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8_unicode_ci,
  `bike_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `info_hash` text COLLATE utf8_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `cycle_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `duplicate_bike_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ignore` tinyint(1) NOT NULL DEFAULT '0',
  `added_bike_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `feedbacks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `feedback_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `feedback_hash` text COLLATE utf8_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `flavor_texts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `frame_materials` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `front_gear_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  `internal` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `standard` tinyint(1) DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `handlebar_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `integrations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `access_token` text COLLATE utf8_unicode_ci,
  `provider_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `information` text COLLATE utf8_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_integrations_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `listicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `list_order` int(11) DEFAULT NULL,
  `body` text COLLATE utf8_unicode_ci,
  `blog_id` int(11) DEFAULT NULL,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `title` text COLLATE utf8_unicode_ci,
  `body_html` text COLLATE utf8_unicode_ci,
  `image_width` int(11) DEFAULT NULL,
  `image_height` int(11) DEFAULT NULL,
  `image_credits` text COLLATE utf8_unicode_ci,
  `image_credits_html` text COLLATE utf8_unicode_ci,
  `crop_top_offset` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `zipcode` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `city` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `street` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `phone` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `shown` tinyint(1) DEFAULT '0',
  `country_id` int(11) DEFAULT NULL,
  `state_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `lock_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `locks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `lock_type_id` int(11) DEFAULT '1',
  `has_key` tinyint(1) DEFAULT '1',
  `has_combination` tinyint(1) DEFAULT NULL,
  `combination` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `key_serial` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `manufacturer_id` int(11) DEFAULT NULL,
  `manufacturer_other` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `lock_model` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_locks_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `mail_snippets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `is_location_triggered` tinyint(1) NOT NULL DEFAULT '0',
  `body` text COLLATE utf8_unicode_ci,
  `address` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `proximity_radius` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `manufacturers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `website` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `frame_maker` tinyint(1) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `total_years_active` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8_unicode_ci,
  `open_year` int(11) DEFAULT NULL,
  `close_year` int(11) DEFAULT NULL,
  `logo` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8_unicode_ci,
  `logo_source` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `memberships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `role` varchar(255) COLLATE utf8_unicode_ci NOT NULL DEFAULT 'member',
  `invited_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_memberships_on_organization_id` (`organization_id`),
  KEY `index_memberships_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `normalized_serial_segments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `segment` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `bike_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `duplicate_bike_group_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_normalized_serial_segments_on_bike_id` (`bike_id`),
  KEY `index_normalized_serial_segments_on_duplicate_bike_group_id` (`duplicate_bike_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `oauth_accessGrants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `resource_owner_id` int(11) NOT NULL,
  `application_id` int(11) NOT NULL,
  `token` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `expires_in` int(11) NOT NULL,
  `redirect_uri` text COLLATE utf8_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `scopes` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_accessGrants_on_token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `oauth_access_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `resource_owner_id` int(11) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `token` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `refresh_token` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `expires_in` int(11) DEFAULT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `scopes` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_access_tokens_on_token` (`token`),
  UNIQUE KEY `index_oauth_access_tokens_on_refresh_token` (`refresh_token`),
  KEY `index_oauth_access_tokens_on_resource_owner_id` (`resource_owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `oauth_applications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `uid` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `secret` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `redirect_uri` text COLLATE utf8_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `owner_id` int(11) DEFAULT NULL,
  `owner_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `is_internal` tinyint(1) NOT NULL DEFAULT '0',
  `can_send_stolenNotifications` tinyint(1) NOT NULL DEFAULT '0',
  `scopes` varchar(255) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_applications_on_uid` (`uid`),
  KEY `index_oauth_applications_on_owner_id_and_owner_type` (`owner_id`,`owner_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `organizationDeals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `deal_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `user_id` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `organizationInvitations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invitee_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `invitee_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `invitee_id` int(11) DEFAULT NULL,
  `organization_id` int(11) DEFAULT NULL,
  `inviter_id` int(11) DEFAULT NULL,
  `redeemed` tinyint(1) DEFAULT NULL,
  `membership_role` varchar(255) COLLATE utf8_unicode_ci DEFAULT 'member',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_organizationInvitations_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `organizations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `available_invitation_count` int(11) DEFAULT '10',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `website` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `short_name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `show_on_map` tinyint(1) DEFAULT NULL,
  `sent_invitation_count` int(11) DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `is_suspended` tinyint(1) NOT NULL DEFAULT '0',
  `auto_user_id` int(11) DEFAULT NULL,
  `org_type` varchar(255) COLLATE utf8_unicode_ci NOT NULL DEFAULT 'shop',
  `access_token` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `new_bike_notification` text COLLATE utf8_unicode_ci,
  `api_access_approved` tinyint(1) NOT NULL DEFAULT '0',
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `wants_to_be_shown` tinyint(1) NOT NULL DEFAULT '0',
  `use_additional_registration_field` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_organizations_on_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `other_listings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bike_id` int(11) DEFAULT NULL,
  `url` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `listing_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `ownerships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bike_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `owner_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `creator_id` int(11) DEFAULT NULL,
  `current` tinyint(1) DEFAULT '0',
  `claimed` tinyint(1) DEFAULT NULL,
  `example` tinyint(1) NOT NULL DEFAULT '0',
  `send_email` tinyint(1) DEFAULT '1',
  `user_hidden` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_ownerships_on_bike_id` (`bike_id`),
  KEY `index_ownerships_on_user_id` (`user_id`),
  KEY `index_ownerships_on_creator_id` (`creator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `paints` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `color_id` int(11) DEFAULT NULL,
  `manufacturer_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `secondary_color_id` int(11) DEFAULT NULL,
  `tertiary_color_id` int(11) DEFAULT NULL,
  `bikes_count` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `payments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `is_current` tinyint(1) DEFAULT '1',
  `is_recurring` tinyint(1) NOT NULL DEFAULT '0',
  `stripe_id` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `last_payment_date` datetime DEFAULT NULL,
  `first_payment_date` datetime DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_payments_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `propulsion_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `publicImages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `listing_order` int(11) DEFAULT '0',
  `imageable_id` int(11) DEFAULT NULL,
  `imageable_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `is_private` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_publicImages_on_imageable_id_and_imageable_type` (`imageable_id`,`imageable_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `rear_gear_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  `internal` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `standard` tinyint(1) DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `recovery_displays` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `stolenRecord_id` int(11) DEFAULT NULL,
  `quote` text COLLATE utf8_unicode_ci,
  `quote_by` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `date_recovered` datetime DEFAULT NULL,
  `link` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `image` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_recovery_displays_on_stolenRecord_id` (`stolenRecord_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `states` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `abbreviation` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_states_on_country_id` (`country_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `stolenNotifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subject` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `receiver_id` int(11) DEFAULT NULL,
  `bike_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `send_dates` text COLLATE utf8_unicode_ci,
  `receiver_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `oauth_application_id` int(11) DEFAULT NULL,
  `reference_url` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_stolenNotifications_on_oauth_application_id` (`oauth_application_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `stolenRecords` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `zipcode` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `city` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `theft_description` text COLLATE utf8_unicode_ci,
  `time` text COLLATE utf8_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `bike_id` int(11) DEFAULT NULL,
  `current` tinyint(1) DEFAULT '1',
  `street` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `date_stolen` datetime DEFAULT NULL,
  `phone` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `phone_for_everyone` tinyint(1) DEFAULT NULL,
  `phone_for_users` tinyint(1) DEFAULT '1',
  `phone_for_shops` tinyint(1) DEFAULT '1',
  `phone_for_police` tinyint(1) DEFAULT '1',
  `police_report_number` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `locking_description` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `lock_defeat_description` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `country_id` int(11) DEFAULT NULL,
  `police_report_department` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `state_id` int(11) DEFAULT NULL,
  `creation_organization_id` int(11) DEFAULT NULL,
  `secondary_phone` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `receive_notifications` tinyint(1) DEFAULT '1',
  `proof_of_ownership` tinyint(1) DEFAULT NULL,
  `date_recovered` datetime DEFAULT NULL,
  `recovered_description` text COLLATE utf8_unicode_ci,
  `index_helped_recovery` tinyint(1) NOT NULL DEFAULT '0',
  `can_share_recovery` tinyint(1) NOT NULL DEFAULT '0',
  `recovery_posted` tinyint(1) DEFAULT '0',
  `recovery_tweet` text COLLATE utf8_unicode_ci,
  `recovery_share` text COLLATE utf8_unicode_ci,
  `create_open311` tinyint(1) NOT NULL DEFAULT '0',
  `tsved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_stolenRecords_on_bike_id` (`bike_id`),
  KEY `index_stolenRecords_on_latitude_and_longitude` (`latitude`,`longitude`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `password` text COLLATE utf8_unicode_ci,
  `last_login` datetime DEFAULT NULL,
  `superuser` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `password_digest` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `banned` tinyint(1) DEFAULT NULL,
  `phone` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `zipcode` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `twitter` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `show_twitter` tinyint(1) NOT NULL DEFAULT '0',
  `website` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `show_website` tinyint(1) NOT NULL DEFAULT '0',
  `show_phone` tinyint(1) DEFAULT '1',
  `show_bikes` tinyint(1) NOT NULL DEFAULT '0',
  `username` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `has_stolen_bikes` tinyint(1) DEFAULT NULL,
  `avatar` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8_unicode_ci,
  `title` text COLLATE utf8_unicode_ci,
  `terms_of_service` tinyint(1) NOT NULL DEFAULT '0',
  `vendor_terms_of_service` tinyint(1) DEFAULT NULL,
  `when_vendor_terms_of_service` datetime DEFAULT NULL,
  `confirmed` tinyint(1) DEFAULT NULL,
  `confirmation_token` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `can_send_many_stolenNotifications` tinyint(1) NOT NULL DEFAULT '0',
  `auth_token` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `stripe_id` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `is_paid_member` tinyint(1) NOT NULL DEFAULT '0',
  `paid_membership_info` text COLLATE utf8_unicode_ci,
  `is_content_admin` tinyint(1) NOT NULL DEFAULT '0',
  `my_bikes_hash` text COLLATE utf8_unicode_ci,
  `is_emailable` tinyint(1) NOT NULL DEFAULT '0',
  `developer` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `wheel_sizes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `iso_bsd` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `priority` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

INSERT INTO schema_migrations (version) VALUES ('20130807222803');

INSERT INTO schema_migrations (version) VALUES ('20130809155956');

INSERT INTO schema_migrations (version) VALUES ('20130820145312');

INSERT INTO schema_migrations (version) VALUES ('20130820150839');

INSERT INTO schema_migrations (version) VALUES ('20130820173657');

INSERT INTO schema_migrations (version) VALUES ('20130821134559');

INSERT INTO schema_migrations (version) VALUES ('20130821135549');

INSERT INTO schema_migrations (version) VALUES ('20130821230157');

INSERT INTO schema_migrations (version) VALUES ('20130903142657');

INSERT INTO schema_migrations (version) VALUES ('20130905215302');

INSERT INTO schema_migrations (version) VALUES ('20131009140156');

INSERT INTO schema_migrations (version) VALUES ('20131013171704');

INSERT INTO schema_migrations (version) VALUES ('20131013172625');

INSERT INTO schema_migrations (version) VALUES ('20131013233351');

INSERT INTO schema_migrations (version) VALUES ('20131018221510');

INSERT INTO schema_migrations (version) VALUES ('20131029004416');

INSERT INTO schema_migrations (version) VALUES ('20131029144536');

INSERT INTO schema_migrations (version) VALUES ('20131030132116');

INSERT INTO schema_migrations (version) VALUES ('20131030161105');

INSERT INTO schema_migrations (version) VALUES ('20131031222251');

INSERT INTO schema_migrations (version) VALUES ('20131101002019');

INSERT INTO schema_migrations (version) VALUES ('20131105010837');

INSERT INTO schema_migrations (version) VALUES ('20131117232341');

INSERT INTO schema_migrations (version) VALUES ('20131202181502');

INSERT INTO schema_migrations (version) VALUES ('20131204230644');

INSERT INTO schema_migrations (version) VALUES ('20131205145316');

INSERT INTO schema_migrations (version) VALUES ('20131211163130');

INSERT INTO schema_migrations (version) VALUES ('20131212161639');

INSERT INTO schema_migrations (version) VALUES ('20131213185845');

INSERT INTO schema_migrations (version) VALUES ('20131216154423');

INSERT INTO schema_migrations (version) VALUES ('20131218201839');

INSERT INTO schema_migrations (version) VALUES ('20131219182417');

INSERT INTO schema_migrations (version) VALUES ('20131221193910');

INSERT INTO schema_migrations (version) VALUES ('20131227132337');

INSERT INTO schema_migrations (version) VALUES ('20131227133553');

INSERT INTO schema_migrations (version) VALUES ('20131227135813');

INSERT INTO schema_migrations (version) VALUES ('20131227151833');

INSERT INTO schema_migrations (version) VALUES ('20131229194508');

INSERT INTO schema_migrations (version) VALUES ('20140103144654');

INSERT INTO schema_migrations (version) VALUES ('20140103161433');

INSERT INTO schema_migrations (version) VALUES ('20140103222943');

INSERT INTO schema_migrations (version) VALUES ('20140103235111');

INSERT INTO schema_migrations (version) VALUES ('20140104011352');

INSERT INTO schema_migrations (version) VALUES ('20140105181220');

INSERT INTO schema_migrations (version) VALUES ('20140106031356');

INSERT INTO schema_migrations (version) VALUES ('20140108195016');

INSERT INTO schema_migrations (version) VALUES ('20140108202025');

INSERT INTO schema_migrations (version) VALUES ('20140108203313');

INSERT INTO schema_migrations (version) VALUES ('20140109001625');

INSERT INTO schema_migrations (version) VALUES ('20140111142521');

INSERT INTO schema_migrations (version) VALUES ('20140111183125');

INSERT INTO schema_migrations (version) VALUES ('20140112004042');

INSERT INTO schema_migrations (version) VALUES ('20140113181408');

INSERT INTO schema_migrations (version) VALUES ('20140114230221');

INSERT INTO schema_migrations (version) VALUES ('20140115041923');

INSERT INTO schema_migrations (version) VALUES ('20140116214759');

INSERT INTO schema_migrations (version) VALUES ('20140116222529');

INSERT INTO schema_migrations (version) VALUES ('20140122181025');

INSERT INTO schema_migrations (version) VALUES ('20140122181308');

INSERT INTO schema_migrations (version) VALUES ('20140204162239');

INSERT INTO schema_migrations (version) VALUES ('20140225203114');

INSERT INTO schema_migrations (version) VALUES ('20140227225103');

INSERT INTO schema_migrations (version) VALUES ('20140301174242');

INSERT INTO schema_migrations (version) VALUES ('20140312191710');

INSERT INTO schema_migrations (version) VALUES ('20140313002428');

INSERT INTO schema_migrations (version) VALUES ('20140426211337');

INSERT INTO schema_migrations (version) VALUES ('20140504234957');

INSERT INTO schema_migrations (version) VALUES ('20140507023948');

INSERT INTO schema_migrations (version) VALUES ('20140510155037');

INSERT INTO schema_migrations (version) VALUES ('20140510163446');

INSERT INTO schema_migrations (version) VALUES ('20140523122545');

INSERT INTO schema_migrations (version) VALUES ('20140524183616');

INSERT INTO schema_migrations (version) VALUES ('20140525163552');

INSERT INTO schema_migrations (version) VALUES ('20140525173416');

INSERT INTO schema_migrations (version) VALUES ('20140525183759');

INSERT INTO schema_migrations (version) VALUES ('20140526141810');

INSERT INTO schema_migrations (version) VALUES ('20140526161223');

INSERT INTO schema_migrations (version) VALUES ('20140614190845');

INSERT INTO schema_migrations (version) VALUES ('20140615230212');

INSERT INTO schema_migrations (version) VALUES ('20140621013108');

INSERT INTO schema_migrations (version) VALUES ('20140621171727');

INSERT INTO schema_migrations (version) VALUES ('20140629144444');

INSERT INTO schema_migrations (version) VALUES ('20140629162651');

INSERT INTO schema_migrations (version) VALUES ('20140629170842');

INSERT INTO schema_migrations (version) VALUES ('20140706170329');

INSERT INTO schema_migrations (version) VALUES ('20140713182107');

INSERT INTO schema_migrations (version) VALUES ('20140720175226');

INSERT INTO schema_migrations (version) VALUES ('20140809102725');

INSERT INTO schema_migrations (version) VALUES ('20140817160101');

INSERT INTO schema_migrations (version) VALUES ('20140830152248');

INSERT INTO schema_migrations (version) VALUES ('20140902230041');

INSERT INTO schema_migrations (version) VALUES ('20140903191321');

INSERT INTO schema_migrations (version) VALUES ('20140907144150');

INSERT INTO schema_migrations (version) VALUES ('20140916141534');

INSERT INTO schema_migrations (version) VALUES ('20140916185511');

INSERT INTO schema_migrations (version) VALUES ('20141006184444');

INSERT INTO schema_migrations (version) VALUES ('20141008160942');

INSERT INTO schema_migrations (version) VALUES ('20141010145930');

INSERT INTO schema_migrations (version) VALUES ('20141025185722');

INSERT INTO schema_migrations (version) VALUES ('20141026172449');

INSERT INTO schema_migrations (version) VALUES ('20141030140601');

INSERT INTO schema_migrations (version) VALUES ('20141031152955');

INSERT INTO schema_migrations (version) VALUES ('20141105172149');

INSERT INTO schema_migrations (version) VALUES ('20141110174307');

INSERT INTO schema_migrations (version) VALUES ('20141210002148');

INSERT INTO schema_migrations (version) VALUES ('20141210031732');

INSERT INTO schema_migrations (version) VALUES ('20141210233551');

INSERT INTO schema_migrations (version) VALUES ('20141217191826');

INSERT INTO schema_migrations (version) VALUES ('20141217200937');

INSERT INTO schema_migrations (version) VALUES ('20141224165646');

INSERT INTO schema_migrations (version) VALUES ('20141231170329');

INSERT INTO schema_migrations (version) VALUES ('20150111193842');

INSERT INTO schema_migrations (version) VALUES ('20150111211009');

INSERT INTO schema_migrations (version) VALUES ('20150122195921');

INSERT INTO schema_migrations (version) VALUES ('20150123233624');

INSERT INTO schema_migrations (version) VALUES ('20150127220842');

INSERT INTO schema_migrations (version) VALUES ('20150208001048');

INSERT INTO schema_migrations (version) VALUES ('20150321233527');

INSERT INTO schema_migrations (version) VALUES ('20150325145515');

INSERT INTO schema_migrations (version) VALUES ('20150402051334');

INSERT INTO schema_migrations (version) VALUES ('20150507222158');

INSERT INTO schema_migrations (version) VALUES ('20150518192613');

INSERT INTO schema_migrations (version) VALUES ('20150701151619');

INSERT INTO schema_migrations (version) VALUES ('20150805160333');

INSERT INTO schema_migrations (version) VALUES ('20150903194549');

INSERT INTO schema_migrations (version) VALUES ('20150916133842');

INSERT INTO schema_migrations (version) VALUES ('20151122175408');

INSERT INTO schema_migrations (version) VALUES ('20160314144745');

INSERT INTO schema_migrations (version) VALUES ('20160317183354');

INSERT INTO schema_migrations (version) VALUES ('20160320154610');

INSERT INTO schema_migrations (version) VALUES ('20160406202125');

INSERT INTO schema_migrations (version) VALUES ('20160425185052');