%% -*- coding: utf-8 -*-
%% Automatically generated, do not edit
%% Generated by gpb_compile version 4.18.0

-ifndef(spear_proto_shared).
-define(spear_proto_shared, true).

-define(spear_proto_shared_gpb_version, "4.18.0").

-ifndef('EVENT_STORE.CLIENT.UUID.STRUCTURED_PB_H').
-define('EVENT_STORE.CLIENT.UUID.STRUCTURED_PB_H', true).
-record('event_store.client.UUID.Structured',
        {most_significant_bits = 0 :: integer() | undefined, % = 1, optional, 64 bits
         least_significant_bits = 0 :: integer() | undefined % = 2, optional, 64 bits
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.UUID_PB_H').
-define('EVENT_STORE.CLIENT.UUID_PB_H', true).
-record('event_store.client.UUID',
        {value                  :: {structured, spear_proto_shared:'event_store.client.UUID.Structured'()} | {string, unicode:chardata()} | undefined % oneof
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.EMPTY_PB_H').
-define('EVENT_STORE.CLIENT.EMPTY_PB_H', true).
-record('event_store.client.Empty',
        {
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.STREAMIDENTIFIER_PB_H').
-define('EVENT_STORE.CLIENT.STREAMIDENTIFIER_PB_H', true).
-record('event_store.client.StreamIdentifier',
        {stream_name = <<>>     :: iodata() | undefined % = 3, optional
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.ALLSTREAMPOSITION_PB_H').
-define('EVENT_STORE.CLIENT.ALLSTREAMPOSITION_PB_H', true).
-record('event_store.client.AllStreamPosition',
        {commit_position = 0    :: non_neg_integer() | undefined, % = 1, optional, 64 bits
         prepare_position = 0   :: non_neg_integer() | undefined % = 2, optional, 64 bits
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.WRONGEXPECTEDVERSION_PB_H').
-define('EVENT_STORE.CLIENT.WRONGEXPECTEDVERSION_PB_H', true).
-record('event_store.client.WrongExpectedVersion',
        {current_stream_revision_option :: {current_stream_revision, non_neg_integer()} | {current_no_stream, spear_proto_shared:'google.protobuf.Empty'()} | undefined, % oneof
         expected_stream_position_option :: {expected_stream_position, non_neg_integer()} | {expected_any, spear_proto_shared:'google.protobuf.Empty'()} | {expected_stream_exists, spear_proto_shared:'google.protobuf.Empty'()} | {expected_no_stream, spear_proto_shared:'google.protobuf.Empty'()} | undefined % oneof
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.ACCESSDENIED_PB_H').
-define('EVENT_STORE.CLIENT.ACCESSDENIED_PB_H', true).
-record('event_store.client.AccessDenied',
        {
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.STREAMDELETED_PB_H').
-define('EVENT_STORE.CLIENT.STREAMDELETED_PB_H', true).
-record('event_store.client.StreamDeleted',
        {stream_identifier = undefined :: spear_proto_shared:'event_store.client.StreamIdentifier'() | undefined % = 1, optional
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.TIMEOUT_PB_H').
-define('EVENT_STORE.CLIENT.TIMEOUT_PB_H', true).
-record('event_store.client.Timeout',
        {
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.UNKNOWN_PB_H').
-define('EVENT_STORE.CLIENT.UNKNOWN_PB_H', true).
-record('event_store.client.Unknown',
        {
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.INVALIDTRANSACTION_PB_H').
-define('EVENT_STORE.CLIENT.INVALIDTRANSACTION_PB_H', true).
-record('event_store.client.InvalidTransaction',
        {
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.MAXIMUMAPPENDSIZEEXCEEDED_PB_H').
-define('EVENT_STORE.CLIENT.MAXIMUMAPPENDSIZEEXCEEDED_PB_H', true).
-record('event_store.client.MaximumAppendSizeExceeded',
        {maxAppendSize = 0      :: non_neg_integer() | undefined % = 1, optional, 32 bits
        }).
-endif.

-ifndef('EVENT_STORE.CLIENT.BADREQUEST_PB_H').
-define('EVENT_STORE.CLIENT.BADREQUEST_PB_H', true).
-record('event_store.client.BadRequest',
        {message = <<>>         :: unicode:chardata() | undefined % = 1, optional
        }).
-endif.

-ifndef('GOOGLE.PROTOBUF.EMPTY_PB_H').
-define('GOOGLE.PROTOBUF.EMPTY_PB_H', true).
-record('google.protobuf.Empty',
        {
        }).
-endif.

-endif.
