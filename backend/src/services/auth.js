import { supabase, supabaseAnon } from '../db/supabase.js';
import { resolveLocationNames } from './location.js';

export async function verifyTokenAndGetProfile(token) {
    console.log('🔍 [Auth Service] Verifying token and fetching profile...');

    const { data: { user }, error } = await supabaseAnon.auth.getUser(token);

    if (error || !user) {
        console.log('❌ [Auth Service] Token verification failed:', error?.message);
        throw new Error('Invalid or expired token');
    }

    console.log('✅ [Auth Service] Token verified for user:', user.id);

    const { data: profile, error: profileError } = await supabase
        .from('users')
        .select('role, verified_rescuer')
        .eq('id', user.id)
        .single();

    if (profileError) {
        console.log('⚠️ [Auth Service] Profile not found, using defaults:', profileError.message);
    }

    const userProfile = {
        id: user.id,
        email: user.email,
        role: profile?.role || 'citizen',
        verifiedRescuer: profile?.verified_rescuer || false,
    };

    console.log('✅ [Auth Service] User profile:', userProfile);
    return userProfile;
}

export async function updateProfile(userId, fullName, role) {
    console.log('📝 [Auth Service] Updating profile for user:', userId);
    console.log('   Full Name:', fullName);
    console.log('   Role:', role);

    const allowedRoles = ['citizen', 'rescuer'];

    if (role && !allowedRoles.includes(role)) {
        console.log('❌ [Auth Service] Invalid role:', role);
        throw new Error('Invalid role');
    }

    const { data, error } = await supabase
        .from('users')
        .update({
            full_name: fullName,
            ...(role && { role }),
        })
        .eq('id', userId)
        .select()
        .single();

    if (error) {
        console.log('❌ [Auth Service] Profile update failed:', error);
        throw error;
    }

    console.log('✅ [Auth Service] Profile updated successfully');
    return data;
}

export async function getProfile(userId) {
    console.log('👤 [Auth Service] Fetching profile for user:', userId);

    const { data, error } = await supabase
        .from('users')
        .select('*, ngo:associated_ngo_id(name, operating_city)')
        .eq('id', userId)
        .single();

    if (error) {
        console.log('❌ [Auth Service] Failed to fetch profile:', error);
        throw error;
    }

    // Get stats for citizen
    const { count: reports_filed } = await supabase
        .from('incidents')
        .select('*', { count: 'exact', head: true })
        .eq('reporter_id', userId);

    const { count: active_reports } = await supabase
        .from('incidents')
        .select('*', { count: 'exact', head: true })
        .eq('reporter_id', userId)
        .in('status', ['pending', 'dispatched', 'active']);

    const { count: animals_helped } = await supabase
        .from('incidents')
        .select('*', { count: 'exact', head: true })
        .eq('reporter_id', userId)
        .eq('status', 'rehabilitated');

    // Get stats for rescuer
    const { count: rescues_completed } = await supabase
        .from('incidents')
        .select('*', { count: 'exact', head: true })
        .eq('assigned_rescuer_id', userId)
        .eq('status', 'rehabilitated'); // Or whatever the completion status is

    const { count: active_rescues } = await supabase
        .from('incidents')
        .select('*', { count: 'exact', head: true })
        .eq('assigned_rescuer_id', userId)
        .in('status', ['dispatched', 'active']);

    // Append stats to data
    data.reports_filed = reports_filed || 0;
    data.active_reports = active_reports || 0;
    data.animals_helped = animals_helped || 0;
    data.rescues_completed = rescues_completed || 0;
    data.active_rescues = active_rescues || 0;

    // Fetch last 5 incidents reported (including completed ones)
    const { data: recent_incidents, error: recent_error } = await supabase
        .from('incidents')
        .select(`
            id, 
            status, 
            created_at, 
            severity, 
            photo_url, 
            title,
            location_name,
            geo_location
        `)
        .eq('reporter_id', userId)
        .order('created_at', { ascending: false })
        .limit(5);

    if (recent_error) {
        console.error('❌ [Auth Service] Failed to fetch recent incidents:', recent_error);
    }

    data.recent_activities = recent_incidents ? await resolveLocationNames(recent_incidents) : [];

    console.log('✅ [Auth Service] Profile fetched:', {
        id: data.id,
        email: data.email,
        full_name: data.full_name,
        role: data.role,
        avatar_url: data.avatar_url ? 'present' : 'null',
        reports_filed: data.reports_filed,
        active_reports: data.active_reports,
        rescues_completed: data.rescues_completed,
        active_rescues: data.active_rescues
    });

    return data;
}

export async function updateAvatar(userId, avatarUrl) {
    console.log('🖼️ [Auth Service] Updating avatar for user:', userId);
    console.log('   Avatar URL:', avatarUrl);

    const { data, error } = await supabase
        .from('users')
        .update({ avatar_url: avatarUrl })
        .eq('id', userId)
        .select()
        .single();

    if (error) {
        console.log('❌ [Auth Service] Avatar update failed:', error);
        throw error;
    }

    console.log('✅ [Auth Service] Avatar updated successfully');
    return data;
}
